defmodule ExYarn.Lockfile do
  @moduledoc false

  alias ExYarn.Lockfile.Dependency

  @enforce_keys [:version, :dependencies, :comments]
  defstruct [:version, :dependencies, :comments]

  @type t() :: %__MODULE__{
          version: integer() | nil,
          dependencies: [Dependency.t()],
          comments: [String.t()]
        }

  @version_regex ~r/^yarn lockfile v(\d+)$/
  @lockfile_version 1

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

    cond do
      length(matches) >= 2 ->
        matches
        |> Enum.at(1)
        |> String.to_integer()

      true ->
        find_version(comments)
    end
  end
end
