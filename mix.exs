defmodule Symconfig.Mixfile do
  use Mix.Project

  def project, do: [
     app: :symconfig,
     version: "0.0.1",
     elixir: "~> 1.0",
     escript: escript_config,
     deps: deps,
  ]

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application, do: [
    applications: [:logger,:ssh],
  ]

  defp escript_config, do: [
    main_module: SymConfig.Cli
  ]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps, do: [
    {:hex_str, github: "mprymek/hex", ref: "5dc1870668"},
    {:exlog, github: "mprymek/exlog", ref: "a383b13a06"},
  ]
end
