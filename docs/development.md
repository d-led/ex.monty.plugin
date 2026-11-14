# Working on the package

What a plugin author needs is in [`README`](readme.html). This page is for
changing the package: where the pieces are, what the tests prove, and how a
version is published.

| Path                                     | What it is                                                    |
| ---------------------------------------- | ------------------------------------------------------------- |
| `lib/monty_plugin.ex`                    | the contract: the `@callback`, the shape of a description, and `conforms?/1` |
| `lib/monty_plugin/registry.ex`           | the `:pg`-backed registry: register, unregister, `lookup/2`, `lookup/3` |
| `lib/monty_plugin/capabilities.ex`       | what a plugin can require of its host, and how `needs` is answered |
| `lib/monty_plugin/application.ex`        | the one process the package starts, and the two variables it reads at boot |
| `test/monty_plugin/registry_across_nodes_test.exs` | the claim the package exists for, as a test: a name joined on one node visible on every node |

## Why `:pg`, and what that costs

`:pg` knows a name on every node and forgets it when a node goes down; a
`Registry` names processes on the node that started it, which is the wrong answer
for a cluster. The cost is that `:pg`'s own scope is global: two systems sharing
a cluster see each other's plugins unless they differ in `PLUGIN_SCOPE`.

A node that is not distributed is a cluster of one, and that is supported on
purpose — the registry answers with what that node offers rather than failing.

## Tests

`mix test` runs the contract, the registry, capabilities, and the cross-node
case. The cross-node test starts and links a peer with `:peer`, so it takes itself
down with the test; a peer outliving its test would be one node's plugin in the
next test's answers. It is tagged `:distributed`, and `test/test_helper.exs`
starts a distributed VM with a name when it can — excluding that one test, with a
sentence saying so, when it cannot. CI runs the rest, then runs the tagged case
again under `elixir --name plugin_ci@127.0.0.1 -S mix test --only distributed`.

`PLUGIN_DISCOVERY=none` and a changed `PLUGIN_SCOPE` are read at boot, so a test
that wants either has to set them before the application starts — the defaults
are what the suite runs on.

## CI and publishing

`.github/workflows/ci.yml` proves a commit, `.github/workflows/docs.yml`
publishes the documentation from `main` to d-led.github.io/ex.monty.plugin, and
`.github/workflows/release.yml` publishes a tag to Hex.

Nothing is published from a branch: `ci` proves a commit, a tag says it is a
version. The version lives in `VERSION` and is written into `mix.exs` (and the
dependency line in the README) by the script that moves it:

```bash
elixir scripts/release.exs bump patch     # 0.1.2 -> 0.1.3, in every file
git add -A && git commit -m "release: 0.1.3" && git push
./scripts/tag_and_push_version.sh          # refuses a dirty tree or red CI
```

The release job needs the `HEX_API_KEY` secret on this repository:

```bash
gh secret set HEX_API_KEY -R d-led/ex.monty.plugin
```

Until the secret is there the tag job stops with that sentence rather than with
an authentication error from Hex. A tag that disagrees with `VERSION` stops it
too, before anything is built. Then watch the run: the package and the
documentation are staged for approval on Hex separately.
