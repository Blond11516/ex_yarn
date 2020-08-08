defmodule ExYarn.Parser do
  @moduledoc """
  Main module for parsing lockfiles (intended for internal use only)

  This module receives the lockfile as input, passes it over to `ExYarn.Token`
  for tokenization and parses the resulting token list to generate the map
  reprsenting the lockfile's contents.
  """

  alias ExYarn.{Token, ParseError}

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
  @spec parse(String.t()) :: {:ok, map()} | {:error, ParseError.t()}
  def parse(input) do
    case Token.tokenize(input) do
      {:error, error} ->
        {:error, error}

      tokens ->
        parser = %__MODULE__{
          tokens: tokens
        }

        case next(parser) do
          {:error, error} ->
            {:error, error}

          {parser, token} ->
            case do_parse(parser, token) do
              {:error, error} -> {:error, error}
              {parser, _token} -> {:ok, parser.result}
            end
        end
    end
  end

  @spec next(t()) :: {t(), Token.t()} | {:error, ParseError.t()}
  defp next(%__MODULE__{tokens: []}) do
    {:error, ParseError.new("No more tokens.", nil)}
  end

  defp next(%__MODULE__{tokens: [token | tokens]} = parser) do
    parser = %{parser | tokens: tokens}

    case token.type do
      :comment ->
        case on_comment(parser, token) do
          {:error, error} -> {:error, error}
          parser -> next(parser)
        end

      _ ->
        {parser, token}
    end
  end

  @spec do_parse(t(), Token.t()) :: {t(), Token.t()} | {:error, ParseError.t()}
  defp do_parse(parser, %Token{type: :new_line}) do
    case next(parser) do
      {:error, error} ->
        {:error, error}

      {parser, token} ->
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
              case next(parser) do
                {:error, error} -> {:error, error}
                {parser, token} -> do_parse(parser, token)
              end
            else
              # the indentation is less than our level
              {parser, token}
            end
          end
        end
    end
  end

  defp do_parse(parser, %Token{type: :indent} = token) do
    if token.value == parser.indent do
      case next(parser) do
        {:error, error} -> {:error, error}
        {parser, next_token} -> do_parse(parser, next_token)
      end
    else
      {parser, token}
    end
  end

  defp do_parse(parser, %Token{type: :eof} = token) do
    {parser, token}
  end

  defp do_parse(parser, %Token{type: :string, value: value}) do
    case next(parser) do
      {:error, error} ->
        {:error, error}

      {parser, token} ->
        case parse_keys(parser, token, [value]) do
          {:error, error} ->
            {:error, error}

          {parser, token, keys} ->
            if token.type == :colon do
              case next(parser) do
                {:error, error} ->
                  {:error, error}

                {parser, token} ->
                  parse_object(parser, token, keys, true)
              end
            else
              parse_object(parser, token, keys, false)
            end
        end
    end
  end

  defp do_parse(_parser, token) do
    {:error, ParseError.new("Unknown token: #{inspect(token)}", token)}
  end

  defp parse_object(parser, token, keys, was_colon) do
    cond do
      Token.valid_prop_value?(token) ->
        # plain value
        parser = update_result(parser, keys, token.value)

        case next(parser) do
          {:error, error} -> {:error, error}
          {parser, token} -> do_parse(parser, token)
        end

      was_colon ->
        # parse object

        object_parser = %__MODULE__{parser | indent: parser.indent + 1, result: %{}}

        case do_parse(object_parser, token) do
          {:error, error} ->
            {:error, error}

          {object_parser, token} ->
            parser = update_result(parser, keys, object_parser.result)
            parser = %__MODULE__{parser | tokens: object_parser.tokens, comments: object_parser.comments}

            if parser.indent != 0 and token.type != :indent do
              {parser, token}
            else
              do_parse(parser, token)
            end
        end

      true ->
        {:error, ParseError.new("Invalid value type", token)}
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
    case next(parser) do
      {:error, error} ->
        {:error, error}

      {parser, token} ->
        case token.type do
          :string ->
            key = token.value

            case next(parser) do
              {:error, error} -> {:error, error}
              {parser, token} -> parse_keys(parser, token, [key | keys])
            end

          _ ->
            {:error, ParseError.new("Expected string", token)}
        end
    end
  end

  defp parse_keys(parser, token, keys) do
    {parser, token, keys}
  end

  @spec on_comment(t(), Token.t()) :: t() | {:error, ParseError.t()}
  defp on_comment(parser, token) do
    if is_binary(token.value) do
      case validate_lockfile_version(token) do
        {:error, error} -> {:error, error}
        :ok -> %__MODULE__{parser | comments: [token.value | parser.comments]}
      end
    else
      {:error, ParseError.new("Expected token value to be a string.", token)}
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
          {:error, ParseError.new("Lockfile version #{version} is not supported.", token)}
        else
          :ok
        end
    end
  end
end
