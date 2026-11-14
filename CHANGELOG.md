# Changelog

## 0.1.3

The front page is for plugin authors, the rules are for whoever changes it.

### Fixed

- **`Registry.offered/0` read every peer's plugins, not this host's.** `:pg`
  replicates a scope across the cluster, so `which_groups/0` made every host
  advertise all of them: two plugin hosts in a live cluster each claimed all six
  of the other's, and a studio's catalogue therefore said one node's experiment
  came from another. It reads `which_local_groups/0` now, and a host that leaves
  takes its own with it, because they were never anybody else's.

### Changed

- `README.md` now opens with the question the package exists to answer and a
  plugin that answers it, instead of with a paragraph about where the
  documentation is generated from. The registry table, the two boot variables and
  the provider example stay; `Install` moved up, because that is what a reader
  does next.
- It also gained what a published package was missing: a licence section, a table
  of where each other question is answered, and what this is *not* — it carries
  no call, supervises no plugin, and chooses none.
- Everything about changing the package moved to `docs/development.md`: the
  layout, why `:pg` rather than a `Registry` and what that costs, the cross-node
  test and how CI runs it, and releasing.
- The API reference groups its modules — `The contract`, `Registry`,
  `Capabilities`, `What the package starts` — instead of one loose list.

## 0.1.2

`needs` can be answered: a host says what it carries.

### Added

- **`MontyPlugin.Capabilities`** — the other half of `needs`: the packages on the
  node's code path, by the name `needs` uses (`ex_tbp_monty_core` is `monty`,
  `ex_quiddity` is `quiddity`, `ex_cadmpeg` is `cadmpeg`), asked of
  `Application` so it is a fact about the build, plus `MONTY_CAPABILITIES`
  reported as written. `MontyPlugin.Registry.identity/0` merges both into the tags
  it publishes, so no caller changes.

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
