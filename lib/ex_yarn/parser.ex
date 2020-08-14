defmodule ExYarn.Parser do
  @moduledoc """
  Main module for parsing lockfiles (intended for internal use only)

  This module receives the lockfile as input, passes it over to `ExYarn.Token`
  for tokenization and parses the resulting token list to generate the map
  reprsenting the lockfile's contents.
  """

  alias ExYarn.{ParseError, Token}

  @version_regex ~r/^yarn lockfile v(\d+)$/
  @lockfile_version 1

  @enforce_keys [:tokens]
  defstruct [:tokens, comments: [], indent: 0, result: %{}]

  @typedoc """
  This type is meant for internal use only and reprsents the parser's state
  """
  @type t() :: %__MODULE__{
          tokens: [Token.t()],
          comments: [String.t()],
          indent: integer(),
          result: map()
        }

  @doc """
  The module's entrypoint

  Receives the lockfile's content as a `String` and returns the parsed map
  representing the lockfile as a `Map`.
  """
  @spec parse(String.t()) :: {:ok, map()}
  def parse(input) do
    tokens = Token.tokenize(input)

    {parser, token} =
      %__MODULE__{tokens: tokens}
      |> next()

    {parser, _token} = do_parse(parser, token)
    {:ok, parser.result}
  end

  @spec next(t()) :: {t(), Token.t()}
  defp next(%__MODULE__{tokens: []}) do
    raise ParseError, message: "No more tokens"
  end

  defp next(%__MODULE__{tokens: [token | tokens]} = parser) do
    parser = %{parser | tokens: tokens}

    case token.type do
      :comment ->
        on_comment(parser, token)
        |> next()

      _ ->
        {parser, token}
    end
  end

  @spec do_parse(t(), Token.t()) :: {t(), Token.t()}
  defp do_parse(parser, %Token{type: :new_line}) do
    {parser, token} = next(parser)

    if parser.indent == 0 do
      # if we have 0 indentation then the next token doesn't matter
      do_parse(parser, token)
    else
      if token.type != :indent do
        # if we have no indentation after a newline then we've gone down a level
        {parser, token}
      else
        if token.value == parser.indent do
          # all is good, the indent is on our level
          {parser, token} = next(parser)
          do_parse(parser, token)
        else
          # the indentation is less than our level
          {parser, token}
        end
      end
    end
  end

  defp do_parse(parser, %Token{type: :indent} = token) do
    if token.value == parser.indent do
      {parser, next_token} = next(parser)
      do_parse(parser, next_token)
    else
      {parser, token}
    end
  end

  defp do_parse(parser, %Token{type: :eof} = token) do
    {parser, token}
  end

  defp do_parse(parser, %Token{type: :string, value: value}) do
    {parser, token} = next(parser)
    {parser, token, keys} = parse_keys(parser, token, [value])

    if token.type == :colon do
      {parser, token} = next(parser)
      parse_object(parser, token, keys, true)
    else
      parse_object(parser, token, keys, false)
    end
  end

  defp do_parse(_parser, token) do
    raise ParseError, message: "Unknown token", token: token
  end

  defp parse_object(parser, token, keys, was_colon) do
    cond do
      Token.valid_prop_value?(token) ->
        # plain value
        parser = update_result(parser, keys, token.value)

        {parser, token} = next(parser)
        do_parse(parser, token)

      was_colon ->
        # parse object

        object_parser = %__MODULE__{parser | indent: parser.indent + 1, result: %{}}

        {object_parser, token} = do_parse(object_parser, token)
        parser = update_result(parser, keys, object_parser.result)
        parser = %__MODULE__{parser | tokens: object_parser.tokens, comments: object_parser.comments}

        if parser.indent != 0 and token.type != :indent do
          {parser, token}
        else
          do_parse(parser, token)
        end

      true ->
        raise ParseError, message: "Invalid value type", token: token
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

  defp parse_keys(parser, %Token{type: :comma}, keys) do
    {parser, token} = next(parser)

    case token.type do
      :string ->
        key = token.value

        {parser, token} = next(parser)
        parse_keys(parser, token, [key | keys])

      _ ->
        raise ParseError, message: "Expected string", token: token
    end
  end

  defp parse_keys(parser, token, keys) do
    {parser, token, keys}
  end

  @spec on_comment(t(), Token.t()) :: t()
  defp on_comment(parser, token) do
    if is_binary(token.value) do
      validate_lockfile_version(token)
      %__MODULE__{parser | comments: [token.value | parser.comments]}
    else
      raise ParseError, message: "Expected token value to be a string", token: token
    end
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
