defmodule ExYarn.Lockfile do
  @moduledoc """
  A small module that wraps `ExYarn.Parser`'s output in an easy to use struct

  This module allows parsing a Yarn lockfile into a struct that exposes the
  file's contents in an easy to use format. This is intended to be used as the
  main entrypoint for the library, but it also exposes functions for manually
  building a Lockfile from `ExYarn.Parser`'s output.
  """

  alias ExYarn.Lockfile.Dependency

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

  @version_regex ~r/^yarn lockfile v(\d+)$/
  @lockfile_version 1

  @doc """
  Build a Lockfile from `ExYarn.Parser`'s output. Raises in case of error.
  """
  @spec from_parse_result!({map(), [String.t()]}) :: ExYarn.Lockfile.t()
  def from_parse_result!({map, comments}) do
    version = find_version(comments)

    if version != nil and version > @lockfile_version do
      raise "Invalid lockfile version #{version}. Only version <= #{@lockfile_version} is supported"
    else
      dependencies =
        for {name, data} <- map do
          Dependency.from_result_map(%{name => data})
        end

      %__MODULE__{version: version, dependencies: dependencies, comments: comments}
    end
  end

  @doc """
  Build a Lockfile from `ExYarn.Parser`'s output. Returns errors in a tuple.
  """
  @spec from_parse_result(any) ::
          {:error, %{:__exception__ => true, :__struct__ => atom, optional(atom) => any}} | {:ok, ExYarn.Lockfile.t()}
  def from_parse_result(parse_result) do
    {:ok, from_parse_result!(parse_result)}
  rescue
    error -> {:error, error}
  end

  defp find_version([]) do
    nil
  end

  defp find_version([comment | comments]) do
    matches = Regex.run(@version_regex, comment)

    if length(matches) >= 2 do
      matches
      |> Enum.at(1)
      |> String.to_integer()
    else
      find_version(comments)
    end
  end
end
