# ex_monty_plugin

What a module in a Monty Studio cluster says about itself, and the registry that
carries the answer between nodes.

A run is assembled from modules — the experiment, the learning modules it steps,
the motor policies that choose where to sense next — and they do not all live in
the same node. A policy that reads a part's B-rep has to run where the part was
opened, because a B-rep handle cannot leave its node. So a cluster asks a module
what it is before it decides where to call it.

```elixir
defmodule FollowChamfers do
  @behaviour MontyPlugin

  @impl true
  def describe do
    %{
      "name" => "follow_chamfers",
      "kind" => :motor_policy,
      "version" => "0.1.0",
      # It reads a part's geometry, and a B-rep handle cannot leave its node.
      "placement" => :owner_only,
      "needs" => [:quiddity]
    }
  end
end

MontyPlugin.conforms?(FollowChamfers.describe())
#=> :ok
```

| module                 | what it answers                                                                                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MontyPlugin`          | the contract: `describe/0` — name, kind, version, placement, needs — and `conforms?/1`, which names the field that is wrong                               |
| `MontyPlugin.Registry` | which plugins the cluster offers, by name and kind, over `:pg`; `lookup/3` asks for a name on a _named_ node, which is what an `:owner_only` plugin needs |

Kinds are `:experiment`, `:learning_module` and `:motor_policy`; placement is
`:anywhere` or `:owner_only`. A learning module is advertised and not routed — it
runs thousands of operations a step, so it is compiled where it runs — while an
experiment and a policy are called once per step, which is what makes a remote
call free.

## Install

```elixir
{:ex_monty_plugin, "~> 0.1.4"}
```

Elixir only. The dependency is the whole setup: `MontyPlugin.Application` starts
`MontyPlugin.Registry` on OTP's `:pg` before anything can ask it a question.

## A provider

A plugin is a process that answers one call:

```elixir
def handle_call(:describe, _from, state), do: {:reply, MyPlugin.describe(), state}
```

The answer is held to `MontyPlugin.conforms?/1`. A plugin that answers unusably is
still listed, with the reason: "nothing there" and "there but unusable" are
different facts to whoever is choosing.

## Two variables, both read at boot

| variable           | what it does                                                                                                                                                                               |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `PLUGIN_SCOPE`     | the `:pg` scope name (default `monty_plugins`). Two systems sharing a cluster that must not see each other's plugins differ here, exactly as they differ in node name                      |
| `PLUGIN_DISCOVERY` | `pg` (default) or `none`. `none` is a deployment that runs its own built-in work and takes no part in a cluster: registration does nothing and a lookup says so, rather than looking empty |

A node that is not distributed is a cluster of one, which is a supported
deployment: the registry answers with what that node offers and nothing else.

The registry does not carry the call, supervise a provider, or rank two of them.
It answers _where_ a plugin is; the call is the caller's, with the `:erpc` or
`GenServer.call/3` it already uses.

## Where to find what

| question                                | where                                                                                          |
| --------------------------------------- | ---------------------------------------------------------------------------------------------- |
| the contract a plugin implements        | [`MontyPlugin`](https://hexdocs.pm/ex_monty_plugin/MontyPlugin.html)                           |
| what the cluster offers, and how to ask | [`MontyPlugin.Registry`](https://hexdocs.pm/ex_monty_plugin/MontyPlugin.Registry.html)         |
| what a plugin can require of its host   | [`MontyPlugin.Capabilities`](https://hexdocs.pm/ex_monty_plugin/MontyPlugin.Capabilities.html) |
| what changed, release by release        | [`CHANGELOG`](https://hexdocs.pm/ex_monty_plugin/changelog.html)                               |
| working on the package                  | [`development`](https://hexdocs.pm/ex_monty_plugin/development.html)                           |

`mix docs` generates the same content as [`llms.txt`](https://d-led.github.io/ex.monty.plugin/llms.txt),
published at [d-led.github.io/ex.monty.plugin](https://d-led.github.io/ex.monty.plugin/) from `main`;
the released version is on [HexDocs](https://hexdocs.pm/ex_monty_plugin).

## Licence

MPL-2.0 (`LICENSE`). The paper this contract serves is in [`CITATION.cff`](CITATION.cff),
which GitHub's _Cite this repository_ button reads; Zenodo mints a DOI per release.
