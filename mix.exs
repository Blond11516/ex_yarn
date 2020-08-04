defmodule ExYarn.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_yarn,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:dialyxir, "~> 1.0", only: :dev},
      {:credo, "~> 1.4", only: :dev}
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
