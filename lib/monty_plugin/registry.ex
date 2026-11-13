defmodule MontyPlugin.Registry do
  @moduledoc """
  Which plugins a cluster offers, by name, on every node.

  `:pg` rather than `Registry`: a `Registry` names processes on the node that
  started it and knows nothing of the others, while `:pg` is OTP's cluster-wide
  process group — a name joined on one node is visible on all of them, and a node
  that goes down takes its names with it.

  `:pg` rather than `Horde.Registry`, and the difference is what a name means.
  Horde is a distributed `Registry` over a δ-CRDT, and it is the right tool for the
  question it answers: one owner per name, handed to another node when a node
  leaves. It supports `keys: :unique` only, and when two nodes register one name it
  settles the conflict by sending the loser an exit signal. A plugin name is
  deliberately *not* unique — every node of an estate may offer `follow_chamfers`,
  and which of them can answer depends on where the part was opened — so the second
  registration is a second provider, not a dead process. `:pg` holds exactly that:
  many members per key, and a member is forgotten when its process or its node goes
  away. A name that must have one owner (a run, a worker) is Horde's question, not
  this one; the two sit in one cluster without argument.

  ## Two variables, both read at boot

  12-factor says the cluster a node belongs to is a start-up decision, so this
  module reads the environment and nothing else:

  * `PLUGIN_SCOPE` — the `:pg` scope name (default `monty_plugins`). Two systems
    on one cluster that must not see each other's plugins differ here, exactly as
    they differ in node name.
  * `PLUGIN_DISCOVERY` — `pg` (the default) or `none`. `none` is a deployment that
    runs its own built-in experiments and wants no cluster at all: registration
    answers `:ok` and does nothing, and a lookup says so rather than pretending
    the cluster is empty.

  ## What a provider is

  A plugin is a process, and it answers `:describe`:

      def handle_call(:describe, _from, state), do: {:reply, MyPlugin.describe(), state}

  The answer is held to `MontyPlugin.conforms?/1`. A plugin that describes itself
  unusably is still *listed* — hiding it would make "nothing there" and "there but
  unusable" look the same — and `describe` in its entry says which field is wrong.
  """

  alias MontyPlugin

  @default_scope :monty_plugins
  @timeout 5_000

  # The same three atoms `MontyPlugin.kinds/0` answers, repeated because a guard
  # cannot call a function. A test holds the two lists to each other, so the copy
  # cannot drift in silence.
  defguardp is_kind(kind) when kind in [:experiment, :learning_module, :motor_policy]

  @typedoc """
  One provider: where to call it, and what it says it is.

  `describe` is `{:ok, map}` when the plugin answered with a description a cluster
  can use, and `{:error, reason}` when it did not answer or answered unusably.
  """
  @type provider :: %{
          kind: MontyPlugin.kind(),
          name: String.t(),
          node: node(),
          pid: pid(),
          describe: {:ok, map()} | {:error, String.t()}
        }

  @doc """
  The child spec that starts the `:pg` process under this scope.

  The package starts it already (`MontyPlugin.Application`), so an application
  does not add this to its own tree — it exists for a test that wants the process
  under its own supervisor. `:pg` is an OTP module and has no `child_spec/1`, which
  is why the start function is named here.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    %{id: :pg, start: {:pg, :start_link, [scope()]}}
  end

  @doc "The `:pg` scope this node registers in, from `PLUGIN_SCOPE`."
  @spec scope() :: atom()
  def scope do
    case System.get_env("PLUGIN_SCOPE") do
      name when name in [nil, ""] -> @default_scope
      name -> String.to_atom(name)
    end
  end

  @doc """
  Whether this node takes part in a cluster at all, from `PLUGIN_DISCOVERY`.

  Read at call time rather than cached, so the answer is the environment's answer
  at every moment; the scope a query uses is fixed by the process started at boot.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    System.get_env("PLUGIN_DISCOVERY", "pg") not in ["none", "false", "0", ""]
  end

  @doc "Offers a process under a name, on this node and therefore on every node."
  @spec register(MontyPlugin.kind(), String.t(), pid()) :: :ok
  def register(kind, name, pid) when is_kind(kind) and is_binary(name) and is_pid(pid) do
    if enabled?(), do: :pg.join(scope(), group(kind, name), pid), else: :ok
  end

  @doc "Withdraws an offer."
  @spec unregister(MontyPlugin.kind(), String.t(), pid()) :: :ok
  def unregister(kind, name, pid) when is_kind(kind) and is_binary(name) and is_pid(pid) do
    if enabled?(), do: :pg.leave(scope(), group(kind, name), pid), else: :ok
  end

  @doc """
  Every provider of a kind, across the cluster, in no particular order.

  One plugin registered on two nodes appears twice, which is the truth: the caller
  picks, and the node it picks is the node the work happens on.
  """
  @spec providers(MontyPlugin.kind()) :: [provider()]
  def providers(kind) when is_kind(kind) do
    if enabled?() do
      scope()
      |> :pg.which_groups()
      |> Enum.filter(&match?({^kind, _name}, &1))
      |> Enum.flat_map(fn {^kind, name} = group ->
        group |> members() |> Enum.map(&provider(kind, name, &1))
      end)
    else
      []
    end
  end

  @doc """
  The one provider under a name.

  A name nobody offers is an error that names the ones there are, because the
  caller is usually a model that can pick another.

  This answers *a* provider, which is right for an `:anywhere` plugin — any node
  may answer — and wrong for an `:owner_only` one, where the address decides
  whether the call can be served at all. That question is `lookup/3`.
  """
  @spec lookup(MontyPlugin.kind(), String.t()) :: {:ok, provider()} | {:error, String.t()}
  def lookup(kind, name) when is_kind(kind) and is_binary(name) do
    if enabled?(), do: found(kind, name), else: switched_off()
  end

  @doc """
  The provider under a name, on a named node.

  This is the question an `:owner_only` plugin asks: a motor policy that reads a
  B-rep has to be called on the node that opened the part, and `lookup/2` answers
  the first provider it finds — which may be the address of a copy that cannot
  serve. The answer when it is not there names the nodes that do offer it, so a
  caller can say which part is where instead of guessing.
  """
  @spec lookup(MontyPlugin.kind(), String.t(), node()) :: {:ok, provider()} | {:error, String.t()}
  def lookup(kind, name, on) when is_kind(kind) and is_binary(name) and is_atom(on) do
    if enabled?(), do: found(kind, name, on), else: switched_off()
  end

  defp found(kind, name) do
    case members(group(kind, name)) do
      [] ->
        {:error, "no #{kind} called #{inspect(name)}; the cluster offers: #{offered(kind)}"}

      [pid | _rest] ->
        {:ok, provider(kind, name, pid)}
    end
  end

  defp found(kind, name, on) do
    case Enum.find(members(group(kind, name)), &(node(&1) == on)) do
      nil ->
        {:error,
         "#{inspect(name)} is not offered on #{on}; it is offered on #{where(kind, name)}"}

      pid ->
        {:ok, provider(kind, name, pid)}
    end
  end

  # Where a name is offered, as a sentence: the nodes, or the fact that nobody
  # offers it at all — two different answers that one empty list would blur.
  defp where(kind, name) do
    case group(kind, name) |> members() |> Enum.map(&node/1) |> Enum.uniq() |> Enum.sort() do
      [] -> "no node at all"
      nodes -> Enum.map_join(nodes, ", ", &to_string/1)
    end
  end

  defp switched_off do
    {:error,
     "plugin discovery is off on this node (PLUGIN_DISCOVERY=#{inspect(System.get_env("PLUGIN_DISCOVERY"))})"}
  end

  defp group(kind, name), do: {kind, name}

  defp members(group), do: :pg.get_members(scope(), group)

  defp provider(kind, name, pid) do
    %{kind: kind, name: name, node: node(pid), pid: pid, describe: describe(pid)}
  end

  defp describe(pid) do
    case GenServer.call(pid, :describe, @timeout) do
      %{} = describe -> conform(describe)
      other -> {:error, ":describe answered #{inspect(other)} rather than a map"}
    end
  catch
    :exit, reason -> {:error, "the plugin did not answer: #{inspect(reason)}"}
  end

  defp conform(describe) do
    case MontyPlugin.conforms?(describe) do
      :ok -> {:ok, describe}
      {:error, reason} -> {:error, "the plugin describes itself wrongly: #{reason}"}
    end
  end

  defp offered(kind) do
    case providers(kind) |> Enum.map(& &1.name) |> Enum.uniq() |> Enum.sort() do
      [] -> "nothing of that kind"
      names -> Enum.join(names, ", ")
    end
  end
end
