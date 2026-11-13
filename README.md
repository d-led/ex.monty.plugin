# ex_monty_plugin

What a Monty plugin tells a cluster, and the registry that carries the answer
between nodes.

A run is assembled from modules — the experiment that drives it, the learning
modules it steps, the motor policies that decide where to sense next — and they do
not all live in the same node. A policy that reads a part's B-rep has to run where
the part was opened, because a B-rep handle cannot leave its node. So a cluster has
to be able to ask a module what it is before it decides where to call it.

| Module | What it answers |
| --- | --- |
| `MontyPlugin` | the contract: `describe/0` — name, kind, version, placement, needs — and `conforms?/1`, which names the field that is wrong |
| `MontyPlugin.Registry` | which plugins the cluster offers, by name and kind, over `:pg`, and the same answer on every node |

```elixir
%{
  "name" => "follow_chamfers",
  "kind" => :motor_policy,
  "version" => "0.1.0",
  # It reads a part's geometry, and a B-rep handle cannot leave its node.
  "placement" => :owner_only,
  "needs" => [:quiddity]
}
```

The three kinds are `:experiment`, `:learning_module` and `:motor_policy`;
placement is `:anywhere` or `:owner_only`. A learning module is advertised rather
than routed — it runs thousands of operations a step, so it is compiled where it
runs — while an experiment and a policy are called once per step, which is what
makes a remote call free.

## What it starts

Adding the dependency is the whole of the setup: `MontyPlugin.Application` starts
the one process this package needs — OTP's `:pg`, under the scope `PLUGIN_SCOPE`
names — before anything that could ask it a question. A forgotten child would
otherwise be a registry that answers `:noproc` on the first call, which says
nothing about the plugin and everything about the boot.

`:pg` and not a `Registry`: `:pg` knows a name on every node and forgets it when a
node goes down; a `Registry` names processes on the node that started it.

`MontyPlugin.Registry.child_spec/1` is there for a test that wants the process
under its own supervisor, not for an application to add again.

## Two variables, both read at boot

| variable | what it does |
| --- | --- |
| `PLUGIN_SCOPE` | the `:pg` scope name (default `monty_plugins`). Two systems sharing a cluster that must not see each other's plugins differ here, exactly as they differ in node name |
| `PLUGIN_DISCOVERY` | `pg` (default) or `none`. `none` is a deployment that runs its own built-in work and takes no part in a cluster: registration does nothing and a lookup says so, rather than looking like an empty cluster |

A node that is not distributed is a cluster of one, which is a supported
deployment — the registry answers with what that node offers and nothing else.

## What a provider is

A plugin is a process that answers one call:

```elixir
def handle_call(:describe, _from, state), do: {:reply, MyPlugin.describe(), state}
```

The answer is held to `MontyPlugin.conforms?/1`. A plugin that answers unusably is
still listed, with the reason — hiding it would make "nothing there" and "there
but unusable" look the same to whoever is choosing.

## Install

```elixir
def deps do
  [
    {:ex_monty_plugin, "~> 0.1"}
  ]
end
```

Elixir only: no NIF, no geometry, no Monty.

## Releasing

Nothing is published from a branch: `ci` proves a commit, a tag says it is a
version. The version lives in `VERSION` and is written into `mix.exs` (and the
dependency line above) by the script that moves it:

```bash
elixir scripts/release.exs bump patch     # 0.1.0 -> 0.1.1, in every file
git add -A && git commit -m "release: 0.1.1" && git push
./scripts/tag_and_push_version.sh          # refuses a dirty tree or red CI
```

The tag is what `.github/workflows/release.yml` publishes from, and that job needs
the `HEX_API_KEY` secret on this repository:

```bash
gh secret set HEX_API_KEY -R d-led/ex_monty_plugin
```

Until the secret is there the tag job stops with that sentence rather than with an
authentication error from Hex. A tag that disagrees with `VERSION` stops it too,
before anything is built.
