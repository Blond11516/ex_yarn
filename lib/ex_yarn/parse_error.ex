defmodule ExYarn.ParseError do
  @moduledoc """
  Represents an error that has occured while parsing a lockfile.

  A `ParseError` contains an error message and, if possible, the `ExYarn.Parser.Token` that caused the error.
  """

  defexception [:message, :token]

  @impl true
  def message(%{message: message, token: token}) do
    "#{message}: #{inspect(token)}"
  end

  def message(%{message: message}) do
    message
  end
end
