defmodule ExYarn.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_yarn,
      version: "0.2.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      source_url: "https://github.com/Blond11516/ex_yarn",
      docs: [
        main: "ExYarn",
        extras: ["README.md"]
      ]
    ]
  end

  defp description, do: "A parser for yarn lockfiles"

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Étienne Lévesque"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Blond11516/ex_yarn"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.5"},

      # Dev dependencies
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22.2", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      quality: [
        "compile",
        "format",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end
end
