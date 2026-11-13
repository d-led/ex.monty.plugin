defmodule MontyPlugin.CapabilitiesTest do
  @moduledoc """
  What a host says it carries.

  This is the half of a placement decision that a plugin cannot make about
  itself: a plugin says what it needs, and the node it would be called on has to
  be able to answer. The packages are asked of the build, the machine tags of the
  deployment, and both are reported as tags the comparison already speaks.
  """

  use ExUnit.Case, async: false

  alias MontyPlugin.Capabilities

  describe "the packages on this node's code path" do
    test "each one is the name a plugin's needs uses" do
      assert Capabilities.carried(&(&1 == :ex_quiddity)) == ["quiddity"]
      assert Capabilities.carried(&(&1 == :ex_cadmpeg)) == ["cadmpeg"]
      assert Capabilities.carried(&(&1 == :ex_tbp_monty_core)) == ["monty"]
    end

    test "a package that is not here is not claimed" do
      assert Capabilities.carried(fn _ -> false end) == []
    end

    test "everything here is reported, sorted, once" do
      assert Capabilities.carried(fn _ -> true end) == ["cadmpeg", "monty", "quiddity"]
    end
  end

  describe "the tags the deployment declared" do
    setup do
      on_exit(fn -> System.delete_env("MONTY_CAPABILITIES") end)
    end

    test "are carried beside the packages, whether or not a package answers them" do
      System.put_env("MONTY_CAPABILITIES", "gpu,world:mujoco")

      assert Capabilities.carried(fn _ -> false end) == ["gpu", "world:mujoco"]
    end

    test "are read as written, since comparing tags is the reader's business" do
      System.put_env("MONTY_CAPABILITIES", " GPU , world:Mujoco ")

      assert Capabilities.carried(fn _ -> false end) == ["GPU", "world:Mujoco"]
    end

    test "are absent when the variable is, and the packages still answer" do
      assert Capabilities.declared() == []
      assert Capabilities.carried(&(&1 == :ex_quiddity)) == ["quiddity"]
    end
  end
end
