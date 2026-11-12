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

Nothing here knows about geometry, Monty, or a CAD file: it is the part of a
cluster that a policy, a learning module and an experiment have in common.
