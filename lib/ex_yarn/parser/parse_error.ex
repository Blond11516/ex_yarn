defmodule ExYarn.Parser.ParseError do
  @moduledoc """
  Represents an error that has occured while parsing a lockfile.

  A `ParseError` contains an error message and, if possible, the `ExYarn.Parser.Token` that caused the error.
  """

  defexception [:message, :token]

  @impl true
  def message(e) do
    case e.token do
      nil -> e.message
      token -> "#{e.message}: #{inspect(token)}"
    end
  end
end
