defmodule MontyPlugin.RegistryTest do
  @moduledoc """
  What the registry promises: a name registered on this node is found by it, a
  name withdrawn is gone, a plugin that describes itself unusably is listed with
  the reason, and a node told not to take part says so rather than looking empty.
  """
  use ExUnit.Case, async: false

  alias MontyPlugin.Registry

  # The registry process is the application's (`MontyPlugin.Application`), so the
  # tests use the scope the node booted with. A registration whose plugin process
  # has stopped is dropped by `:pg` itself, so one test's names do not reach the
  # next.
  setup do
    description = %{
      "name" => "follow_chamfers",
      "kind" => :motor_policy,
      "version" => "0.1.0",
      "placement" => :owner_only,
      "needs" => [:quiddity]
    }

    plugin = start_supervised!({__MODULE__.Plugin, describe: description})
    %{plugin: plugin}
  end

  test "a plugin registered under a name is found by it, with its description", %{plugin: plugin} do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    assert {:ok, provider} = Registry.lookup(:motor_policy, "follow_chamfers")
    assert provider.node == node()
    assert provider.pid == plugin
    assert {:ok, %{"needs" => [:quiddity]}} = provider.describe
  end

  test "is listed among the providers of its kind, and not another's", %{plugin: plugin} do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    assert Enum.map(Registry.providers(:motor_policy), & &1.name) == ["follow_chamfers"]
    assert Registry.providers(:experiment) == []
  end

  test "a name asked for on a node that does not offer it says where it is offered", %{
    plugin: plugin
  } do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    assert {:ok, provider} = Registry.lookup(:motor_policy, "follow_chamfers", node())
    assert provider.node == node()

    assert {:error, message} = Registry.lookup(:motor_policy, "follow_chamfers", :other@nohost)
    assert message =~ "not offered on other@nohost"
    assert message =~ to_string(node())
  end

  test "a name nobody offers anywhere is told apart from one offered elsewhere" do
    assert {:error, message} = Registry.lookup(:experiment, "nowhere", :other@nohost)
    assert message =~ "it is offered on no node at all"
  end

  test "a withdrawn plugin is no longer offered", %{plugin: plugin} do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)
    :ok = Registry.unregister(:motor_policy, "follow_chamfers", plugin)

    assert Registry.providers(:motor_policy) == []
    assert {:error, message} = Registry.lookup(:motor_policy, "follow_chamfers")
    assert message =~ "the cluster offers: nothing of that kind"
  end

  test "an unusable description is listed with the field that is wrong" do
    spec =
      Supervisor.child_spec(
        {__MODULE__.Plugin,
         describe: %{"name" => "nameless", "kind" => :motor_policy, "placement" => :anywhere}},
        id: :nameless
      )

    plugin = start_supervised!(spec)

    :ok = Registry.register(:motor_policy, "nameless", plugin)

    assert {:ok, provider} = Registry.lookup(:motor_policy, "nameless")
    assert {:error, message} = provider.describe
    assert message =~ "describes itself wrongly"
    assert message =~ "`version` is missing"
  end

  test "a plugin that does not answer is listed, because silence is not absence" do
    plugin = start_supervised!(__MODULE__.Silent)
    :ok = Registry.register(:learning_module, "quiet", plugin)

    assert {:ok, provider} = Registry.lookup(:learning_module, "quiet")
    assert {:error, message} = provider.describe
    assert message =~ "did not answer"
  end

  test "a node told not to take part registers nothing and says why" do
    System.put_env("PLUGIN_DISCOVERY", "none")
    on_exit(fn -> System.delete_env("PLUGIN_DISCOVERY") end)

    refute Registry.enabled?()
    assert Registry.providers(:motor_policy) == []

    assert {:error, message} = Registry.lookup(:motor_policy, "follow_chamfers")
    assert message =~ "plugin discovery is off on this node"
  end

  test "the scope is a name a deployment can choose" do
    assert Registry.scope() == :monty_plugins

    System.put_env("PLUGIN_SCOPE", "monty_plugins_staging")
    on_exit(fn -> System.delete_env("PLUGIN_SCOPE") end)

    assert Registry.scope() == :monty_plugins_staging
  end

  test "the child spec starts :pg under the scope, since :pg has none of its own" do
    assert %{id: :pg, start: {:pg, :start_link, [:monty_plugins]}} = Registry.child_spec([])
  end

  test "the node tells a peer what it is, and what it offers, as one answer", %{plugin: plugin} do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    identity = Registry.identity()

    assert identity.node == node()
    assert identity.version == to_string(Application.spec(:ex_monty_plugin, :vsn))
    assert identity.plugins == [%{"kind" => "motor_policy", "name" => "follow_chamfers"}]
    refute identity.web
  end

  test "the tags are what is registered: one for hosting plugins, one per kind", %{
    plugin: plugin
  } do
    assert Registry.identity().capabilities == ["plugin"]

    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    assert Registry.identity().capabilities == ["plugin", "plugin:motor_policy"]
  end

  test "a host told not to take part offers nothing, and still answers", %{plugin: plugin} do
    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    System.put_env("PLUGIN_DISCOVERY", "none")
    on_exit(fn -> System.delete_env("PLUGIN_DISCOVERY") end)

    assert Registry.identity().node == node()
    assert Registry.identity().plugins == []
    assert Registry.identity().capabilities == ["plugin"]
  end

  # A plugin's `needs` is answered against the host's tags, so a host that
  # carried nothing would make every need unanswerable — which is what a host
  # whose tags came only from its own registry did.
  test "a host says what it carries, so a plugin's needs can be answered", %{plugin: plugin} do
    System.put_env("MONTY_CAPABILITIES", "gpu")
    on_exit(fn -> System.delete_env("MONTY_CAPABILITIES") end)

    :ok = Registry.register(:motor_policy, "follow_chamfers", plugin)

    assert "gpu" in Registry.identity().capabilities
    assert "plugin:motor_policy" in Registry.identity().capabilities
  end

  defmodule Plugin do
    @moduledoc false
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :describe))

    @impl true
    def init(describe), do: {:ok, describe}

    @impl true
    def handle_call(:describe, _from, describe), do: {:reply, describe, describe}
  end

  defmodule Silent do
    @moduledoc false
    use GenServer

    def child_spec(_opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}

    def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok)

    @impl true
    def init(:ok), do: {:ok, :ok}

    @impl true
    def handle_call(:describe, _from, _state), do: exit(:not_answering_that)
  end
end
