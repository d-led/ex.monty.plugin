defmodule MontyPluginTest do
  @moduledoc """
  What the contract promises: a description that says what a cluster needs is
  accepted, and one that does not is refused with the field that is wrong.
  """
  use ExUnit.Case, async: true

  @description %{
    "name" => "follow_chamfers",
    "kind" => :motor_policy,
    "version" => "0.1.0",
    "placement" => :owner_only,
    "needs" => [:quiddity]
  }

  test "a description with everything a cluster asks for conforms" do
    assert MontyPlugin.conforms?(@description) == :ok
  end

  test "a description without a name is refused, and the field is named" do
    assert {:error, message} = MontyPlugin.conforms?(Map.delete(@description, "name"))
    assert message =~ "`name` is missing"
    assert message =~ "a string"
  end

  test "a kind nobody can call is refused, and the kinds are listed" do
    assert {:error, message} = MontyPlugin.conforms?(%{@description | "kind" => :script})

    assert message =~ "`kind` is :script"
    assert message =~ ":motor_policy"
  end

  test "a placement that says nothing about where it may run is refused" do
    assert {:error, message} =
             MontyPlugin.conforms?(Map.put(@description, "placement", :somewhere))

    assert message =~ ":owner_only"
  end

  test "needs is a list, because it is a list of engines" do
    assert {:error, message} = MontyPlugin.conforms?(Map.put(@description, "needs", :quiddity))
    assert message =~ "a list of atoms"
  end

  test "something that is not a description at all is refused as such" do
    assert {:error, message} = MontyPlugin.conforms?("follow_chamfers")
    assert message =~ "a description is a map"
  end

  test "the kinds are the three things a run is made of" do
    assert MontyPlugin.kinds() == [:experiment, :learning_module, :motor_policy]
    assert MontyPlugin.placements() == [:anywhere, :owner_only]
  end
end
