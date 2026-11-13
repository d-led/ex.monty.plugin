# Changelog

## 0.1.1

The name, said out loud, and a node that can be seen.

### Added

- **`MontyPlugin.Registry.identity/0`** — what a plugin host tells another node's
  poller: this node's name, the package's version, and the tags it derives from
  what is registered rather than from an environment variable (`plugin`, and
  `plugin:<kind>` per kind offered). A studio's node list asks every peer for its
  version and its tags with one `:rpc`; without this answer a plugin host is a
  peer that looks dead while it is offering three plugins, and with it the list
  can ask twice and mean one thing. `offered/0` is the same list on its own.

### Changed

- **The docs call the package the Elixir Monty Studio Plugin.** "Monty" alone is the
  upstream project's reserved name, so the prose names the product (an Elixir Monty
  Studio plugin, and a run of one) and calls the ported upstream code "the
  framework's". Module names, the app atom and the package name are unchanged — the
  port is module for module.

## 0.1.0

The contract and the registry, on their own.

### Added

- **`MontyPlugin`** — `describe/0` as a behaviour: `name`, `kind`, `version`,
  `placement`, `needs`; the three kinds and the two placements; `conforms?/1`,
  which answers `:ok` or names the first field that a cluster cannot use.
- **`MontyPlugin.Registry`** — providers by kind and by name over `:pg`, one
  scope per deployment (`PLUGIN_SCOPE`), switched off with `PLUGIN_DISCOVERY=none`,
  and an unusable description reported with its field rather than offered.
  `lookup/3` asks for a name **on a named node**, which is the question an
  `:owner_only` plugin asks: a policy that reads a B-rep has to be called where the
  part was opened, and the answer when it is not there names the nodes that do
  offer it.

- **`MontyPlugin.Application`** — starts the `:pg` scope the registry uses, unless
  `PLUGIN_DISCOVERY=none`; a host application adds nothing.
- **A two-node test** — a plugin offered on a peer node is found here with its
  description, and one withdrawn there leaves the list here.

Nothing here knows about geometry, a CAD file, or a run: it is the part of a
cluster that a policy, a learning module and an experiment have in common.
