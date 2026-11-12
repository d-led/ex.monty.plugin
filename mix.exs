defmodule MontyPlugin.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/d-led/ex_monty_plugin"

  def project do
    [
      app: :ex_monty_plugin,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      docs: docs(),
      name: "ExMontyPlugin",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp description do
    "What a Monty plugin tells a cluster, and the registry that carries the " <>
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
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
