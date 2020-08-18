defmodule ExYarn do
  @moduledoc """
  The library's main module

  This module should be used as the public entrypoint of the library. It exposes
  a single function, `parse/2`, which is used to parse a lockfile's contents.

  **Note on performance:** This library was built in part as a learning exercise and therefore does not necessarily
  apply the best possible practices and tools when it comes to code quality and performance. If performance is important
  to you, I recommend using Dorgan's library ([hex.pm](https://hex.pm/packages/yarn_parser),
  [Github](https://github.com/doorgan/yarn_parser)), which uses
  [NimbleParsec](https://hexdocs.pm/nimble_parsec/NimbleParsec.html) for better performance.

  ## Example

      iex> input = ~s(
      ...>foo:
      ...>  "bar" true
      ...>  foo 10
      ...>  foobar: barfoo
      ...>)
      ...> ExYarn.parse(input)
      {:ok, :success, {%{"foo" => %{"bar" => true, "foo" => 10, "foobar" => "barfoo"}}, []}}
  """

  alias ExYarn.Parser
  alias ExYarn.Parser.ParseError

  @merge_conflict_ancestor "|||||||"
  @merge_conflict_end ">>>>>>>"
  @merge_conflict_sep "======="
  @merge_conflict_start "<<<<<<<"

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
  @spec parse(any, any) ::
          parsingError()
          | {:ok, :merge | :success, {map(), [String.t()]}}
  def parse(str, file_loc \\ "lockfile") do
    {type, {result, comments}} = parse!(str, file_loc)
    {:ok, type, {result, Enum.reverse(comments)}}
  rescue
    e in ParseError -> {:error, e}
    e in YamlElixir.ParsingError -> {:error, e}
    e in FunctionClauseError -> {:error, e}
  end

  @doc """
  Receives the lockfile's contents, and optionnally the lockfile's name as inputs
  and returns the parsed result

  Similar to `parse/2` except it will raise in case of errors.
  """
  @spec parse!(String.t(), String.t()) :: {:merge | :success, {map(), [String.t()]}}
  def parse!(str, file_loc \\ "lockfile") do
    str = String.replace_prefix(str, "\uFEFF", "")

    if has_merge_conflict?(str) do
      parse_with_conflict(str, file_loc)
    else
      parse_file(str, file_loc)
    end
  end

  defp extract_conflict_variants(str) do
    {variant1, variant2} =
      String.split(str, ~r/\r?\n/)
      |> extract_conflict_variants([], [])

    {Enum.join(variant1, "\n"), Enum.join(variant2, "\n")}
  end

  defp extract_conflict_variants([line | lines], variants1, variants2) do
    if String.starts_with?(line, @merge_conflict_start) do
      {variant1, lines} = get_first_variant(lines, variants1, false)
      {variant2, common_end} = get_second_variant(lines, variants2)
      {variant1 ++ common_end, variant2 ++ common_end}
    else
      variants1 = [line | variants1]
      variants2 = [line | variants2]
      extract_conflict_variants(lines, variants1, variants2)
    end
  end

  defp get_first_variant([line | lines], variants1, skip) do
    cond do
      line == @merge_conflict_sep -> {Enum.reverse(variants1), lines}
      skip or String.starts_with?(line, @merge_conflict_ancestor) -> get_first_variant(lines, variants1, true)
      true -> get_first_variant(lines, [line | variants1], skip)
    end
  end

  defp get_second_variant([line | lines], variants2) do
    if String.starts_with?(line, @merge_conflict_end) do
      {Enum.reverse(variants2), lines}
    else
      get_second_variant(lines, [line | variants2])
    end
  end

  defp has_merge_conflict?(str) do
    String.contains?(str, @merge_conflict_start) and
      String.contains?(str, @merge_conflict_sep) and
      String.contains?(str, @merge_conflict_end)
  end

  @spec parse_file(String.t(), String.t()) :: {:success, {map(), [String.t()]}}
  defp parse_file(str, file_loc) do
    if String.ends_with?(file_loc, ".yml") do
      parse_file_yaml(str)
    else
      parse_file_yarn(str)
    end
  end

  defp parse_file_yaml(str) do
    result = YamlElixir.read_from_string!(str)
    {:success, {result, []}}
  end

  defp parse_file_yarn(str) do
    {:ok, result, comments} = Parser.parse(str)
    {:success, {result, comments}}
  rescue
    e in ParseError ->
      try do
        parse_file_yaml(str)
      rescue
        _ in YamlElixir.ParsingError -> reraise e, __STACKTRACE__
      end
  end

  @spec parse_with_conflict(String.t(), String.t()) :: {:merge | :success, {map(), [String.t()]}}
  defp parse_with_conflict(str, file_loc) do
    {variant1, variant2} = extract_conflict_variants(str)

    {_, parse_result_1} = parse!(variant1, file_loc)
    {_, parse_result_2} = parse!(variant2, file_loc)

    merge_conflict_results(parse_result_1, parse_result_2)
  end

  defp merge_conflict_results({result_map_1, comments_1}, {result_map_2, comments_2}) do
    {:merge, {Map.merge(result_map_1, result_map_2), Enum.uniq(comments_1 ++ comments_2)}}
  end
end
