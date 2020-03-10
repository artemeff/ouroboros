defmodule Ouroboros.MixProject do
  use Mix.Project

  def project do
    [
      app: :ouroboros,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(e) when e in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.2"},
      {:ecto_sql, ">= 0.0.0", only: [:dev, :test]},
      {:postgrex, ">= 0.0.0", only: [:dev, :test]},
      {:ex_machina, "~> 2.3", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "Cursor based pagination for Ecto"
  end

  defp package do
    [
      name: :ouroboros,
      maintainers: ["Yuri Artemev"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/artemeff/ouroboros"}
    ]
  end
end
