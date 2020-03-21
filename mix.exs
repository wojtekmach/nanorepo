defmodule NanoRepo.MixProject do
  use Mix.Project

  def project do
    [
      app: :nanorepo,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:public_key, :inets, :ssl],
      mod: {NanoRepo.Application, []}
    ]
  end

  defp deps do
    [
      {:hex_core, "~> 0.6.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end

  defp escript() do
    [
      main_module: NanoRepo.CLI
    ]
  end
end
