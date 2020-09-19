defmodule ExYarn do
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
      {:ok, {%{"foo" => %{"bar" => true, "foo" => 10, "foobar" => "barfoo"}}, [" a comment"]}}
  """

  alias ExYarn.{Lockfile, Parser}

  @spec parse(binary) :: {:error, Exception.t()} | {:ok, {map(), [binary]}}
  def parse(lockfile_content) do
    do_parse(lockfile_content)
  end

  @spec parse!(binary) :: {map, [binary]}
  def parse!(lockfile_content) do
    case parse(lockfile_content) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @spec parse_to_lockfile(binary) :: {:error, binary | Exception.t()} | {:ok, Lockfile.t()}
  def parse_to_lockfile(lockfile_content) do
    case parse(lockfile_content) do
      {:ok, parse_result} -> build_lockfile(parse_result)
      {:error, error} -> {:error, error}
    end
  end

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
