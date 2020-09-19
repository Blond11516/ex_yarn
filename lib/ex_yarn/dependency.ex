defmodule ExYarn.Dependency do
  @moduledoc """
  An NPM dependency

  This module represents an NPM dependency as parsed by ExYarn. It does not
  provide any utility functions and is therefore intended for data
  representation only.
  """

  @enforce_keys [:name, :version, :resolved]
  defstruct [:name, :version, :resolved, :integrity, :dependencies, :optional_dependencies]

  @type dep_name :: String.t()
  @type dep_version :: String.t()

  @typedoc """
  The represenation of a dependency.
  """
  @type t() :: %__MODULE__{
          name: dep_name(),
          version: dep_version(),
          resolved: String.t(),
          integrity: String.t() | nil,
          dependencies: [sub_dependency()],
          optional_dependencies: [sub_dependency()]
        }

  @typedoc """
  The representation of a sub-dependency.
  """
  @type sub_dependency :: {dep_name(), dep_version()}

  @doc """
  Creates a Dependency struct from a parsed dependency map

  Receives a map as returned by the `ExYarn.Parser` and returns
  the corresponding Dependency struct.
  """
  @spec from_result_map(map()) :: t()
  def from_result_map(result) do
    name =
      Map.keys(result)
      |> List.first()

    data = result[name]

    %__MODULE__{
      name: name,
      version: data["version"],
      resolved: data["resolved"],
      integrity: Map.get(data, "integrity", nil),
      dependencies: Map.get(data, "dependencies", %{}) |> build_dependencies(),
      optional_dependencies: Map.get(data, "optionalDependencies", %{}) |> build_dependencies()
    }
  end

  defp build_dependencies(deps_map) do
    for name <- Map.keys(deps_map) do
      {name, Map.fetch!(deps_map, name)}
    end
  end
end
