defmodule ExYarn.Parser do
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
      ...> ExYarn.Parser.parse(input)
      {:ok, {%{"foo" => %{"bar" => true, "foo" => 10, "foobar" => "barfoo"}}, [" a comment"]}}
  """

  alias ExYarn.Parsing.FileParser

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

  @spec parse_file!(String.t()) :: {:ok, {map, [String.t()]}}
  def parse_file!(file_path) do
    File.read!(file_path)
    |> parse!()
  end

  @spec parse_file(String.t()) ::
          {:error, %{:__exception__ => true, :__struct__ => atom, optional(atom) => any}}
          | {:ok, {map, [String.t()]}}
  def parse_file(file_path) do
    parse_file!(file_path)
  rescue
    e -> {:error, e}
  end

  @spec parse!(String.t()) :: {:ok, {map, [String.t()]}}
  def parse!(file_content) do
    FileParser.parse!(file_content)
  end

  @spec parse(String.t()) ::
          {:error, %{:__exception__ => true, :__struct__ => atom, optional(atom) => any}}
          | {:ok, {map, [String.t()]}}
  def parse(file_content) do
    parse!(file_content)
  rescue
    e -> {:error, e}
  end
end
