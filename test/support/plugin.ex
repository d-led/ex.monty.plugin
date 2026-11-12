defmodule MontyPlugin.TestPlugin do
  @moduledoc """
  A plugin for the cross-node test: it says what it was told to say, and nothing
  else.

  It lives in `test/support` rather than inside the test file because a module
  defined in a test file exists in that VM's memory only — and the test asks a
  *second* node to start it, where a module it cannot load is an `:undef`.
  """
  use GenServer

  @doc "Starts one, unlinked and unnamed, so it outlives the call that started it."
  @spec start_unlinked(map()) :: {:ok, pid()}
  def start_unlinked(describe), do: GenServer.start(__MODULE__, describe)

  @impl true
  def init(describe), do: {:ok, describe}

  @impl true
  def handle_call(:describe, _from, describe), do: {:reply, describe, describe}
end
