# A peer node needs a distributed VM, and `mix test` does not start one. The test
# that starts a second node is tagged `:distributed`, so a plain run excludes it
# rather than failing on a capability the VM does not have; CI starts a VM with a
# name and asks for it.
distributed? =
  case :net_kernel.start([:"plugin_test@127.0.0.1", :longnames]) do
    {:ok, _pid} -> true
    {:error, {:already_started, _pid}} -> true
    {:error, _reason} -> false
  end

unless distributed? do
  IO.puts("not distributed: the test that starts a second node is excluded")
end

ExUnit.start(exclude: if(distributed?, do: [], else: [:distributed]))
