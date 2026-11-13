defmodule MontyPlugin.Capabilities do
  @moduledoc """
  What a plugin host can reach, as the tags a plugin's `needs` are checked
  against.

  `MontyPlugin`'s `needs` says what a plugin calls while it answers: `:quiddity`
  for the geometry, `:cadmpeg` for the file, `:monty` for the framework. A
  cluster can only hold a plugin to that answer if the host publishes the other
  half — what it carries — so a host's tags are its plugins *and* this.

  ## Two kinds of tag

  * A **package** is on the node's code path or it is not, and that is a fact
    about the build rather than a promise in a deployment file. `Application`
    answers it, so `carried/0` asks; the tag is the name `needs` uses, which is
    the table below and nothing else in this package.
  * What only the machine knows — `gpu`, `world:mujoco`, a licence server —
    arrives in `MONTY_CAPABILITIES`, comma-separated, the same variable a studio
    node reads when it says what it can do.

  The declared tags are reported as written. A tag is compared, not parsed, and
  the comparison that decides a placement is the reader's
  (`ExTbpMonty.Cluster.Capabilities.offers?/2`, which normalises both sides), so
  a spelling difference between two deployments is not a tag this module has to
  correct.
  """

  @variable "MONTY_CAPABILITIES"

  # The need, and the application that answers it. These three are the
  # vocabulary `MontyPlugin` documents; a fourth is a line here, and a plugin
  # that asks for a need this table does not know is served only by a node whose
  # deployment declared it.
  @packages %{
    monty: :ex_tbp_monty_core,
    quiddity: :ex_quiddity,
    cadmpeg: :ex_cadmpeg
  }

  @doc """
  Every tag this host carries, sorted and without duplicates.

  `installed?` is how the package question is asked — `Application` unless a
  caller says otherwise. A test says otherwise, because the three packages are
  other applications and are not on this package's own code path; a deployment
  reads it as it is.
  """
  @spec carried((atom() -> boolean)) :: [String.t()]
  def carried(installed? \\ &application_here?/1) do
    (declared() ++ packages(installed?))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  The tags `MONTY_CAPABILITIES` adds, in the order written.

  Empty when it is unset, which is an answer: the packages are still reported,
  and the machine has said nothing about itself.
  """
  @spec declared() :: [String.t()]
  def declared do
    @variable
    |> System.get_env("")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp packages(installed?) do
    for {need, application} <- @packages, installed?.(application) do
      Atom.to_string(need)
    end
  end

  # The .app file is on the code path, so this node can load the application's
  # modules. It is not a claim that the application is running, and not a claim
  # that a NIF inside it shipped: a node that carries the geometry answers
  # `quiddity` and still fails a call if its build is broken.
  defp application_here?(application), do: Application.spec(application, :vsn) != nil
end
