defmodule ExYarn.Lockfile.Dependency do
  @moduledoc false

  @enforce_keys [:name, :version, :resolved]
  defstruct [:name, :version, :resolved, :integrity, :dependencies, :optional_dependencies]

  @type t() :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          resolved: String.t(),
          integrity: String.t() | nil,
          dependencies: [sub_dependency()],
          optional_dependencies: [sub_dependency()]
        }

  @type sub_dependency :: {String.t(), String.t()}

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
