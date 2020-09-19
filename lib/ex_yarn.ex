defmodule ExYarn do
  alias ExYarn.{Lockfile, ParseError, Parser}

  @spec parse(binary) :: {:error, ParseError.t()} | {:ok, {map(), [binary]}}
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

  @spec parse_to_lockfile(binary) ::
          {:error, ParseError.t()}
          | {:error, %{:__exception__ => true, :__struct__ => atom, optional(atom) => any}}
          | {:ok, Lockfile.t()}
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
