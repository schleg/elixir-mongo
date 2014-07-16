defmodule Mongo.Mixfile do
  use Mix.Project

  def project do
    [ app: :"elixir-mongo",
      name: "elixir-mongo",
      version: "0.3.0",
      elixir: "~> 0.14.1",
      source_url: "https://github.com/checkiz/elixir-mongo",
      deps: deps(Mix.env),
      docs: &docs/0 ]
  end

  # Configuration for the OTP application
  def application do
    [
      applications: [],
      env: [host: {"127.0.0.1", 27017}]
    ]
  end
  
  # Returns the list of dependencies for prod
  defp deps(:prod) do
    [
      {:bson, github: "checkiz/elixir-bson", tag: "0.3"}
    ]
  end

  # Returns the list of dependencies for docs
  defp deps(:docs) do
    deps(:prod) ++
      [{ :ex_doc, github: "elixir-lang/ex_doc" }]
  end
  defp deps(_), do: deps(:prod)

  defp docs do
    [ #readme: false,
      #main: "README",
      source_ref: System.cmd("git rev-parse --verify --quiet HEAD") ]
  end

end
