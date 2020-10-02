defmodule ExYarn do
  @moduledoc """
  ExYarn is a small library for parsing [Yarn](https://yarnpkg.com/) lockfiles in Elixir. Only the version 1 of Yarn
  lockfiles is currently supported.

  The library allows you to parse either to a plain Elixir map, or to a utility type, `ExYarn.Lockfile`, which makes
  manipulating the parsed dependencies a little easier.

  #### Note on performance
  This library was built in part as a learning exercise and therefore does not necessarily
  apply the best possible practices and tools when it comes to code quality and performance. If performance is important
  to you, I recommend using Dorgan's library ([hex.pm](https://hex.pm/packages/yarn_parser),
  [Github](https://github.com/doorgan/yarn_parser)), which uses
  [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html) for better performance.

  ## Example
  ### Parsing to a map

      iex> input = ~s(
      ...># yarn lockfile v1
      ...>"@babel/code-frame@7.8.3":
      ...>  version "7.10.4"
      ...>  resolved "https://registry.yarnpkg.com/@babel/code-frame/-/code-frame-7.10.4.tgz#168da1a36e90da68ae8d49c0f1b48c7c6249213a"
      ...>  integrity sha512-vG6SvB6oYEhvgisZNFRmRCUkLz11c7rp+tbNTynGqc6mS1d5ATd/sGyV6W0KZZnXRKMTzZDRgQT3Ou9jhpAfUg==
      ...>  dependencies:
      ...>    "@babel/highlight" "^7.10.4"
      ...>)
      ...> ExYarn.parse(input)
      {
        :ok,
        {
          %{
            "@babel/code-frame@7.8.3" => %{
              "version" => "7.10.4",
              "resolved" => "https://registry.yarnpkg.com/@babel/code-frame/-/code-frame-7.10.4.tgz#168da1a36e90da68ae8d49c0f1b48c7c6249213a",
              "integrity" => "sha512-vG6SvB6oYEhvgisZNFRmRCUkLz11c7rp+tbNTynGqc6mS1d5ATd/sGyV6W0KZZnXRKMTzZDRgQT3Ou9jhpAfUg==",
              "dependencies" => %{"@babel/highlight" => "^7.10.4"}
            }
          },
          [" yarn lockfile v1"]
        }
      }

  ### Parsing to a `ExYarn.Lockfile`

      iex> input = ~s(
      ...># yarn lockfile v1
      ...>"@babel/code-frame@7.8.3":
      ...>  version "7.10.4"
      ...>  resolved "https://registry.yarnpkg.com/@babel/code-frame/-/code-frame-7.10.4.tgz#168da1a36e90da68ae8d49c0f1b48c7c6249213a"
      ...>  integrity sha512-vG6SvB6oYEhvgisZNFRmRCUkLz11c7rp+tbNTynGqc6mS1d5ATd/sGyV6W0KZZnXRKMTzZDRgQT3Ou9jhpAfUg==
      ...>  dependencies:
      ...>    "@babel/highlight" "^7.10.4"
      ...>)
      ...>ExYarn.parse_to_lockfile(input)
      {
        :ok,
        %ExYarn.Lockfile{
          version: 1,
          dependencies: [
            %ExYarn.Dependency{
              name: "@babel/code-frame@7.8.3",
              version: "7.10.4",
              resolved: "https://registry.yarnpkg.com/@babel/code-frame/-/code-frame-7.10.4.tgz#168da1a36e90da68ae8d49c0f1b48c7c6249213a",
              integrity: "sha512-vG6SvB6oYEhvgisZNFRmRCUkLz11c7rp+tbNTynGqc6mS1d5ATd/sGyV6W0KZZnXRKMTzZDRgQT3Ou9jhpAfUg==",
              dependencies: [
                {"@babel/highlight", "^7.10.4"}
              ],
              optional_dependencies: []
            }
          ],
          comments: [" yarn lockfile v1"]}}
  """

  alias ExYarn.{Lockfile, Parser}

  @doc """
  Takes the lockfile's content as input and returns the parsed map
  """
  @spec parse(binary) :: {:error, Exception.t()} | {:ok, {map(), [binary]}}
  def parse(lockfile_content) do
    do_parse(lockfile_content)
  end

  @doc """
  Same as `ExYarn.parse/1` but raises errors instead of returning them
  """
  @spec parse!(binary) :: {map, [binary]}
  def parse!(lockfile_content) do
    case parse(lockfile_content) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Takes the lockfile's content as input and returns a parsed `ExYarn.Lockfile`
  """
  @spec parse_to_lockfile(binary) :: {:error, binary | Exception.t()} | {:ok, Lockfile.t()}
  def parse_to_lockfile(lockfile_content) do
    case parse(lockfile_content) do
      {:ok, parse_result} -> build_lockfile(parse_result)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Same as `ExYarn.parse_to_lockfile/1` but raises errors instead of returning them
  """
  @spec parse_to_lockfile!(binary) :: ExYarn.Lockfile.t()
  def parse_to_lockfile!(lockfile_content) do
    case parse_to_lockfile(lockfile_content) do
      {:ok, lockfile} -> lockfile
      {:error, error} -> raise error
    end
  end

  defp do_parse(lockfile_content) do
    parse_result =
      lockfile_content
      |> String.replace_prefix("\uFEFF", "")
      |> Parser.parse()

    case parse_result do
      {:ok, result, comments} -> {:ok, {result, Enum.reverse(comments)}}
      {:error, error} -> {:error, error}
    end
  end

  defp build_lockfile(parse_result) do
    parse_result
    |> Lockfile.from_parse_result()
  end
end
