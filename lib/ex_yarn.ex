defmodule ExYarn do
  @moduledoc """
     Documentation for `ExYarn`.
  """

  alias ExYarn.{ParseError, Parser}

  @merge_conflict_ancestor "|||||||"
  @merge_conflict_end ">>>>>>>"
  @merge_conflict_sep "======="
  @merge_conflict_start "<<<<<<<"

  @type parseResult ::
          {:ok, :merge | :success, map()}
          | {:error, ParseError.t()}
          | {:error, YamlElixir.FileNotFoundError}
          | {:error, YamlElixir.ParsingError}
          | {:error, :conflict, FunctionClauseError}

  @spec parse(String.t(), String.t()) :: parseResult()
  def parse(str, file_loc \\ "lockfile") do
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

  @spec parse_file(String.t(), String.t()) :: parseResult()
  defp parse_file(str, file_loc) do
    if String.ends_with?(file_loc, ".yml") do
      parse_file_yaml(str)
    else
      parse_file_yarn(str, file_loc)
    end
  end

  defp parse_file_yaml(str) do
    case YamlElixir.read_from_string(str) do
      {:error, error} -> {:error, error}
      {:ok, result} -> {:ok, {:success, result}}
    end
  end

  defp parse_file_yarn(str, file_loc) do
    case Parser.parse(str, file_loc) do
      {:error, error} ->
        case YamlElixir.read_from_string(str) do
          {:error, _} -> {:error, error}
          {:ok, result} -> {:ok, :success, result}
        end

      {:ok, result} ->
        {:ok, :success, result}
    end
  end

  @spec parse_with_conflict(String.t(), String.t()) :: parseResult()
  defp parse_with_conflict(str, file_loc) do
    {variant1, variant2} = extract_conflict_variants(str)

    try do
      parse_result_1 = parse(variant1, file_loc)
      parse_result_2 = parse(variant2, file_loc)

      interpret_conflict_results(parse_result_1, parse_result_2)
    rescue
      e in FunctionClauseError -> {:error, :conflict, e}
    end
  end

  defp interpret_conflict_results({:error, error}, _parse_result_2) do
    {:error, error}
  end

  defp interpret_conflict_results(_parse_result_1, {:error, error}) do
    {:error, error}
  end

  defp interpret_conflict_results(parse_result_1, parse_result_2) do
    {:ok, _, parsed_obj_1} = parse_result_1
    {:ok, _, parsed_obj_2} = parse_result_2
    {:ok, :merge, Map.merge(parsed_obj_1, parsed_obj_2)}
  end
end
