defmodule ExYarn.Lockfile do
  @moduledoc """
  A small module that wraps `ExYarn.Parser`'s output in an easy to use struct

  This module allows parsing a Yarn lockfile into a struct that exposes the
  file's contents in an easy to use format.
  """

  alias ExYarn.Dependency

  @enforce_keys [:version, :dependencies, :comments]
  defstruct [:version, :dependencies, :comments]

  @typedoc """
  The representation of a lockfile
  """
  @type t() :: %__MODULE__{
          version: integer() | nil,
          dependencies: [Dependency.t()],
          comments: [String.t()]
        }

  @version_regex ~r/^[ ]?yarn lockfile v(\d+)$/
  @lockfile_version 1

  @doc """
  Build a Lockfile from `ExYarn.Parser`'s output.
  """
  @spec from_parse_result({any, maybe_improper_list}) :: {:error, binary} | {:ok, ExYarn.Lockfile.t()}
  def from_parse_result({parsed_map, comments}) do
    version = find_version(comments)

    if version != nil and version > @lockfile_version do
      {:error, "Invalid lockfile version #{version}. Only version <= #{@lockfile_version} is supported"}
    else
      dependencies =
        for {name, data} <- parsed_map do
          Dependency.from_result_map(%{name => data})
        end

      {:ok, %__MODULE__{version: version, dependencies: dependencies, comments: comments}}
    end
  end

  defp find_version([]) do
    nil
  end

  defp find_version([comment | comments]) do
    matches = Regex.run(@version_regex, comment)

    case matches do
      nil -> find_version(comments)
      matches -> Enum.at(matches, 1) |> String.to_integer()
    end
  end
end
