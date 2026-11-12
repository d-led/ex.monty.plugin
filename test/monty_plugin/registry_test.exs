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
