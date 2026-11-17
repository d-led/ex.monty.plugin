defmodule MontyPlugin.MixProject do
  use Mix.Project

  @version "0.1.4"
  @source_url "https://github.com/d-led/ex.monty.plugin"

  def project do
    [
      app: :ex_monty_plugin,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      docs: docs(),
      name: "Elixir Monty Studio Plugin",
      source_url: @source_url
    ]
  end

  # `test/support` is compiled into the application in the test build, because the
  # cross-node test asks a second VM to start a module — and a module defined in a
  # test file exists only in the memory of the VM that ran the test.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [mod: {MontyPlugin.Application, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp description do
    "What an Elixir Monty Studio plugin tells a cluster, and the registry that " <>
      "carries the " <>
      "answer between nodes: a behaviour for experiments, learning modules and " <>
      "motor policies, and a `:pg`-backed lookup that knows a name on every node " <>
      "and forgets it when a node goes down."
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs),
      licenses: ["MPL-2.0"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Dmitry Ledentsov"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "main",
      extras: ["README.md", "CHANGELOG.md", "docs/development.md"],
      groups_for_modules: [
        "The contract": [MontyPlugin],
        Registry: [MontyPlugin.Registry],
        Capabilities: [MontyPlugin.Capabilities],
        "What the package starts": [MontyPlugin.Application]
      ]
    ]
  end
end
