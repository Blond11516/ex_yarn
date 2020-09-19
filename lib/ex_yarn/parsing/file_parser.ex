defmodule ExYarn.Parsing.FileParser do
  @moduledoc """
  The library's main module

  This module should be used as the main entrypoint of the library. It exposes
  a single function, `parse/2` (along with its error raising variant,
  parse!/2`), which is used to parse a lockfile's contents.

  **Note on performance:** This library was built in part as a learning exercise and therefore does not necessarily
  apply the best possible practices and tools when it comes to code quality and performance. If performance is important
  to you, I recommend using Dorgan's library ([hex.pm](https://hex.pm/packages/yarn_parser),
  [Github](https://github.com/doorgan/yarn_parser)), which uses
  [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html) for better performance.

  ## Example

      iex> input = ~s(
      ...># a comment
      ...>foo:
      ...>  "bar" true
      ...>  foo 10
      ...>  foobar: barfoo
      ...>)
      ...> ExYarn.parse(input)
      {:ok, :success, {%{"foo" => %{"bar" => true, "foo" => 10, "foobar" => "barfoo"}}, [" a comment"]}}
  """

  alias ExYarn.Parsing.{DependenciesParser, ParseError}

  @typedoc """
  The different types of errors that can be returned by `parse/2`

  Types details:
  - `{:error, ParseError}`: There was an error while parsing the file as a Yarn lockfile.
  - `{:error, YamlElixir.ParsingError}`: There was an error while parsing the file as a YAML file.
  - `{:error, FunctionClauseError}`: The lockfile contained a merge conflict which could not be parsed successfully.
  """
  @type parsingError ::
          {:error, ParseError}
          | {:error, YamlElixir.ParsingError}
          | {:error, FunctionClauseError}

  @doc """
  Receives the lockfile's contents, and optionnally the lockfile's name as inputs
  and returns the parsed result

  The lockfile's name is used to determine whether to parse the lockfile as an
  official yarn lockfile (i.e. with yarn's custom format) or as a regular YAML
  file. The function defaults to parsing the file as a yarn lockfile.
  """
  @spec parse(any) ::
          parsingError()
          | {:ok, {map(), [String.t()]}}
  def parse(str) do
    parse!(str)
  rescue
    e -> {:error, e}
  end

  @doc """
  Receives the lockfile's contents, and optionnally the lockfile's name as inputs
  and returns the parsed result

  Similar to `parse/2` except it will raise in case of errors.
  """
  @spec parse!(String.t()) :: {:ok, {map(), [String.t()]}}
  def parse!(str) do
    str = String.replace_prefix(str, "\uFEFF", "")

    parse_file(str)
  end

  @spec parse_file(String.t()) :: {:ok, {map(), [String.t()]}}
  defp parse_file(str) do
    {:ok, result, comments} = DependenciesParser.parse(str)
    {:ok, {result, Enum.reverse(comments)}}
  end
end
