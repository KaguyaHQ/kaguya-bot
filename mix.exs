defmodule Kaguyabot.MixProject do
  use Mix.Project

  def project do
    [
      app: :kaguyabot,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Kaguyabot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.8"},
      {:dotenvy, "~> 1.0.0"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, "~> 0.19.3"}
    ]
  end
end
