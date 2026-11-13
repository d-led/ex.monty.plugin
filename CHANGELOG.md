# Changelog

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
