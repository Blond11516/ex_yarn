defmodule ExYarn.Parsing.DependenciesParser do
  @moduledoc """
  Main module for parsing lockfiles (intended for internal use only)

  This module receives the lockfile as input, passes it over to `ExYarn.Parser.Token`
  for tokenization and parses the resulting token list to generate the map
  reprsenting the lockfile's contents.
  """

  alias ExYarn.Parsing.{ParseError, Token}

  @version_regex ~r/^yarn lockfile v(\d+)$/
  @lockfile_version 1

  @enforce_keys [:tokens]
  defstruct [:tokens, comments: [], indent: 0, result: %{}, current_token: nil]

  @typedoc """
  The parser's state. Intended for internal use only.
  """
  @type t() :: %__MODULE__{
          tokens: [Token.t()],
          comments: [String.t()],
          indent: integer(),
          result: map(),
          current_token: Token.t() | nil
        }

  @doc """
  The module's entrypoint

  Receives the lockfile's content as a `String` and returns the parsed map
  representing the lockfile as a `Map` and the list of comments.
  """
  @spec parse(String.t()) :: {:ok, map(), [String.t()]}
  def parse(input) do
    tokens = Token.tokenize(input)

    %__MODULE__{result: result, comments: comments} =
      %__MODULE__{tokens: tokens}
      |> next()
      |> do_parse()

    {:ok, result, comments}
  end

  @spec next(t()) :: t()
  defp next(%__MODULE__{tokens: []}) do
    raise ParseError, message: "No more tokens"
  end

  defp next(%__MODULE__{tokens: [token | tokens]} = parser) do
    parser = %{parser | tokens: tokens, current_token: token}

    case parser.current_token.type do
      :comment ->
        on_comment(parser)
        |> next()

      _ ->
        parser
    end
  end

  @spec do_parse(t()) :: t()
  defp do_parse(%__MODULE__{current_token: %Token{type: :new_line}} = parser) do
    parser = next(parser)

    if parser.indent == 0 do
      # if we have 0 indentation then the next token doesn't matter
      do_parse(parser)
    else
      handle_indent(parser)
    end
  end

  defp do_parse(%__MODULE__{current_token: %Token{type: :indent}} = parser) do
    %__MODULE__{current_token: token} = parser

    if parser.current_token.value == parser.indent do
      next(parser)
      |> do_parse()
    else
      %__MODULE__{parser | current_token: token}
    end
  end

  defp do_parse(%__MODULE__{current_token: %Token{type: :eof}} = parser) do
    parser
  end

  defp do_parse(%__MODULE__{current_token: %Token{type: :string, value: value}} = parser) do
    {parser, keys} =
      next(parser)
      |> parse_keys([value])

    if parser.current_token.type == :colon do
      next(parser)
      |> parse_object(keys, true)
    else
      parse_object(parser, keys, false)
    end
  end

  defp do_parse(%__MODULE__{current_token: token}) do
    raise ParseError, message: "Unknown token", token: token
  end

  defp handle_indent(%__MODULE__{current_token: %Token{type: :indent}} = parser) do
    if parser.current_token.value == parser.indent do
      # all is good, the indent is on our level
      next(parser)
      |> do_parse()
    else
      # the indentation is less than our level
      parser
    end
  end

  defp handle_indent(parser) do
    parser
  end

  defp parse_object(parser, keys, was_colon) do
    cond do
      Token.valid_prop_value?(parser.current_token) ->
        parse_plain_value_object(parser, keys)

      was_colon ->
        parse_complex_object(parser, keys)

      true ->
        raise ParseError, message: "Invalid value type", token: parser.current_token
    end
  end

  defp parse_plain_value_object(parser, keys) do
    update_result(parser, keys, parser.current_token.value)
    |> next()
    |> do_parse()
  end

  defp parse_complex_object(parser, keys) do
    object_parser = %__MODULE__{parser | indent: parser.indent + 1, result: %{}}

    object_parser = do_parse(object_parser)
    parser = update_result(parser, keys, object_parser.result)

    parser = %__MODULE__{
      parser
      | tokens: object_parser.tokens,
        comments: object_parser.comments,
        current_token: object_parser.current_token
    }

    if parser.indent != 0 and parser.current_token.type != :indent do
      parser
    else
      do_parse(parser)
    end
  end

  defp update_result(parser, keys, value) do
    new_results =
      for key <- keys,
          into: %{} do
        {key, value}
      end

    %__MODULE__{parser | result: Map.merge(parser.result, new_results)}
  end

  defp parse_keys(%__MODULE__{current_token: %Token{type: :comma}} = parser, keys) do
    parser = next(parser)

    case parser.current_token.type do
      :string ->
        key = parser.current_token.value

        next(parser)
        |> parse_keys([key | keys])

      _ ->
        raise ParseError, message: "Expected string", token: parser.current_token
    end
  end

  defp parse_keys(parser, keys) do
    {parser, keys}
  end

  @spec on_comment(t()) :: t()
  defp on_comment(%__MODULE__{current_token: %Token{value: value}} = parser) when is_binary(value) do
    validate_lockfile_version(parser.current_token)
    %__MODULE__{parser | comments: [parser.current_token.value | parser.comments]}
  end

  defp on_comment(%__MODULE__{current_token: current_token}) do
    raise ParseError, message: "Expected token value to be a string", token: current_token
  end

  defp validate_lockfile_version(token) do
    comment = String.trim(token.value)

    case Regex.run(@version_regex, comment) do
      nil ->
        :ok

      captures ->
        version = Enum.at(captures, 1)

        if String.to_integer(version) > @lockfile_version do
          raise ParseError, message: "Lockfile version #{version} is not supported", token: token
        else
          :ok
        end
    end
  end
end
