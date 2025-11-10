defmodule Sortio.MixProject do
  use Mix.Project

  def project do
    [
      app: :sortio,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Sortio.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, "~> 0.21"},
      {:bcrypt_elixir, "~> 3.3"},
      {:guardian, "~> 2.4"},
      {:uniq, "~> 0.6"},
      {:oban, "~> 2.20"},

      # Dev dependencies
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test, runtime: false}
    ]
  end
end
