defmodule MontyPlugin.RegistryAcrossNodesTest do
  @moduledoc """
  The claim this package exists for — a name joined on one node is visible on every
  node — as a test rather than a sentence.

  The peer is started by the test and linked, so it goes when the test does: a peer
  outliving its test would be one node's plugin in the next test's answers.
  """
  use ExUnit.Case, async: false

  @moduletag :distributed

  alias MontyPlugin.Registry

  test "a plugin offered by another node is found here, with its description" do
    peer = peer()

    {:ok, plugin} =
      :rpc.call(peer, MontyPlugin.TestPlugin, :start_unlinked, [description()])

    :ok = :rpc.call(peer, Registry, :register, [:motor_policy, "far_policy", plugin])

    assert {:ok, provider} =
             eventually(
               fn -> Registry.lookup(:motor_policy, "far_policy") end,
               &match?({:ok, _}, &1)
             )

    assert provider.node == peer
    assert provider.pid == plugin
    assert {:ok, %{"placement" => :owner_only}} = provider.describe
  end

  test "a plugin withdrawn elsewhere leaves the list here" do
    peer = peer()
    {:ok, plugin} = :rpc.call(peer, MontyPlugin.TestPlugin, :start_unlinked, [description()])
    :ok = :rpc.call(peer, Registry, :register, [:experiment, "gone_soon", plugin])

    assert {:ok, _provider} =
             eventually(
               fn -> Registry.lookup(:experiment, "gone_soon") end,
               &match?({:ok, _}, &1)
             )

    :ok = :rpc.call(peer, Registry, :unregister, [:experiment, "gone_soon", plugin])

    assert {:error, message} =
             eventually(
               fn -> Registry.lookup(:experiment, "gone_soon") end,
               &match?({:error, _}, &1)
             )

    assert message =~ ~s(no experiment called "gone_soon")
  end

  defp description do
    %{
      "name" => "far_policy",
      "kind" => :motor_policy,
      "version" => "0.1.0",
      "placement" => :owner_only,
      "needs" => [:quiddity]
    }
  end

  defp peer do
    name = :"plugin_peer_#{System.unique_integer([:positive])}"

    {:ok, _peer, peer_node} = :peer.start_link(%{name: name, longnames: true})

    :ok = :rpc.call(peer_node, :code, :add_paths, [:code.get_path()])
    {:ok, _apps} = :rpc.call(peer_node, Application, :ensure_all_started, [:ex_monty_plugin])
    peer_node
  end

  defp eventually(what, accepted, attempts \\ 40)

  defp eventually(what, _accepted, 0), do: flunk("never became true: #{inspect(what.())}")

  defp eventually(what, accepted, attempts) do
    case what.() do
      answer ->
        if accepted.(answer), do: answer, else: retry(what, accepted, attempts)
    end
  end

  defp retry(what, accepted, attempts) do
    Process.sleep(50)
    eventually(what, accepted, attempts - 1)
  end
end
