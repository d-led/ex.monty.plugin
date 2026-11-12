defmodule MontyPlugin.Application do
  @moduledoc """
  The one process this package needs: the `:pg` scope plugins register in.

  It is started here rather than left to the host application because a forgotten
  child is a registry that answers `:noproc` on the first call, which says nothing
  about the plugin and everything about the boot. An application that wants the
  registry *not* started says `PLUGIN_DISCOVERY=none`, which is one variable in one
  place rather than a line in every supervision tree.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = if MontyPlugin.Registry.enabled?(), do: [MontyPlugin.Registry], else: []

    Supervisor.start_link(children, strategy: :one_for_one, name: MontyPlugin.Supervisor)
  end
end
