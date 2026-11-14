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

  test "a plugin offered elsewhere is asked for on the node that offers it" do
    peer = peer()
    {:ok, plugin} = :rpc.call(peer, MontyPlugin.TestPlugin, :start_unlinked, [description()])
    :ok = :rpc.call(peer, Registry, :register, [:motor_policy, "owner_only_policy", plugin])

    assert {:ok, _provider} =
             eventually(
               fn -> Registry.lookup(:motor_policy, "owner_only_policy") end,
               &match?({:ok, _}, &1)
             )

    # The question an `:owner_only` plugin asks: a B-rep cannot leave its node, so
    # the address decides whether the call can be served at all.
    assert {:ok, provider} = Registry.lookup(:motor_policy, "owner_only_policy", peer)
    assert provider.node == peer

    assert {:error, message} = Registry.lookup(:motor_policy, "owner_only_policy", node())
    assert message =~ "not offered on #{node()}"
    assert message =~ to_string(peer)
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

  # `offered/0` is what a peer reads to learn what this node brings, and it is the
  # half a catalogue lists. `:pg` replicates a scope's groups across the cluster,
  # so reading all of them made every host claim every peer's plugins — which is
  # how one node's experiment came to be shown as another node's.
  test "a node offers its own plugins and not its peers'" do
    peer = peer()
    {:ok, plugin} = :rpc.call(peer, MontyPlugin.TestPlugin, :start_unlinked, [description()])
    :ok = :rpc.call(peer, Registry, :register, [:experiment, "theirs.not_ours", plugin])

    # The registration is visible from here — that is the package's whole point …
    assert {:ok, _provider} =
             eventually(
               fn -> Registry.lookup(:experiment, "theirs.not_ours") end,
               &match?({:ok, _}, &1)
             )

    # … and it is still theirs to offer.
    assert Registry.offered() == []
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
