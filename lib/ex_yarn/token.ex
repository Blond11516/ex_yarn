defmodule ExYarn.Token do
  @moduledoc false

  alias ExYarn.ParseError

  @type tokenType ::
          :boolean
          | :string
          | :identifier
          | :eof
          | :colon
          | :new_line
          | :comment
          | :indent
          | :invalid
          | :number
          | :comma

  @valid_prop_value_token [:boolean, :string, :number]

  @enforce_keys [:type, :value, :line, :col]
  defstruct [:line, :col, :type, :value]

  @type t() :: %__MODULE__{
          line: integer(),
          col: integer(),
          type: tokenType(),
          value: any()
        }

  @spec valid_prop_value?(t()) :: boolean
  def valid_prop_value?(%__MODULE__{type: type}) do
    type in @valid_prop_value_token
  end

  @spec tokenize(String.t()) :: [t()] | {:error, ParseError.t()}
  def tokenize(input) do
    case tokenize(input, false, 1, 0, []) do
      {:error, error} -> {:error, error}
      tokens -> Enum.reverse(tokens)
    end
  end

  @spec tokenize(String.t(), boolean(), integer(), integer(), [t()]) ::
          [t()] | {:error, ParseError.t()}
  defp tokenize("", _last_new_line, line, col, tokens) do
    [build_token(line, col, :eof) | tokens]
  end

  defp tokenize(input, last_new_line, line, col, tokens) do
    case generate_next_token(input, last_new_line, line, col) do
      {:error, error} ->
        {:error, error}

      {chop, token, line, col} ->
        tokens =
          case token do
            nil -> tokens
            token -> [token | tokens]
          end

        tokens =
          case chop do
            0 -> [build_token(line, col, :invalid) | tokens]
            _ -> tokens
          end

        col = col + chop

        last_new_line = String.at(input, 0) == "\n" or String.at(input, 0) == "\r\n"

        input = String.slice(input, chop..-1)

        tokenize(input, last_new_line, line, col, tokens)
    end
  end

  @spec build_token(integer(), integer(), tokenType, any()) :: t()
  defp build_token(line, col, type, value \\ nil) do
    %__MODULE__{line: line, col: col, type: type, value: value}
  end

  @spec generate_next_token(String.t(), boolean(), integer(), integer()) ::
          {integer(), t() | nil, integer(), integer()} | {:error, ParseError.t()}
  defp generate_next_token("\n" <> _rest, _last_new_line, line, _col) do
    line = line + 1
    col = 0
    {1, build_token(line, col, :new_line), line, col}
  end

  defp generate_next_token("\r\n" <> _rest, _last_new_line, line, _col) do
    line = line + 1
    col = 1
    {1, build_token(line, col, :new_line), line, col}
  end

  defp generate_next_token("#" <> rest, _last_new_line, line, col) do
    {val, val_length} =
      case Regex.run(~r/^.*?\n/, rest) do
        [capture | _] ->
          val_length = String.length(capture) - 1
          val = String.slice(capture, 0, val_length)
          {val, val_length}

        nil ->
          {rest, String.length(rest)}
      end

    {val_length + 1, build_token(line, col, :comment, val), line, col}
  end

  defp generate_next_token(" " <> _rest, false, line, col) do
    {1, nil, line, col}
  end

  defp generate_next_token(" " <> _rest = input, true, line, col) do
    indent_size =
      Regex.run(~r/^ */, input)
      |> List.first()
      |> String.length()

    if rem(indent_size, 2) == 0 do
      {indent_size, build_token(line, col, :indent, indent_size / 2), line, col}
    else
      {:error, ParseError.new("Invalid number of spaces.", build_token(line, col, :invalid))}
    end
  end

  defp generate_next_token("\"" <> _rest = input, _last_new_line, line, col) do
    string_length =
      Regex.run(~r/^".*?(\\\\|[^\\])"/, input)
      |> List.first()
      |> String.length()

    val = String.slice(input, 1, string_length - 2)

    {string_length, build_token(line, col, :string, val), line, col}
  end

  defp generate_next_token("true" <> _rest, _last_new_line, line, col) do
    {4, build_token(line, col, :boolean, true), line, col}
  end

  defp generate_next_token("false" <> _rest, _last_new_line, line, col) do
    {5, build_token(line, col, :boolean, false), line, col}
  end

  defp generate_next_token(":" <> _rest, _last_new_line, line, col) do
    {1, build_token(line, col, :colon), line, col}
  end

  defp generate_next_token("," <> _rest, _last_new_line, line, col) do
    {1, build_token(line, col, :comma), line, col}
  end

  defp generate_next_token(input, _last_new_line, line, col) do
    cond do
      Regex.match?(~r/^[0-9]/, input) ->
        val =
          Regex.run(~r/^[0-9]*/, input)
          |> List.first()

        {String.length(val), build_token(line, col, :number, String.to_integer(val)), line, col}

      Regex.match?(~r/^[a-zA-Z\/.-]/, input) ->
        {name, name_length} =
          case Regex.run(~r/.*?[: \r\n,]/, input) do
            nil -> {input, String.length(input)}
            [name | _] -> {name, String.length(name) - 1}
          end

        name = String.slice(name, 0, name_length)

        {name_length, build_token(line, col, :string, name), line, col}

      true ->
        {0, build_token(line, col, :invalid), line, col}
    end
  end
end
