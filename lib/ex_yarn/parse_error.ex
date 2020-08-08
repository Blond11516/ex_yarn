defmodule ExYarn.ParseError do
  @moduledoc """
  Represents an error that has occured while parsing a lockfile.

  An error contains an error message and, if possible, the `ExYarn.Token` that caused the error.
  """

  alias ExYarn.Token

  @enforce_keys [:error, :token]
  defstruct [:error, :token]

  @typedoc """
  A parsing error

  Error content:
  - `:error`: A `String` explaining what went wrong
  - `:token`: If available, the `ExYarn.Token` that caused the error
  """
  @type t() :: %__MODULE__{
          error: String.t(),
          token: Token.t() | nil
        }

  @doc """
  Returns a new `ExYarn.ParseError`
  """
  @spec new(String.t(), Token.t() | nil) :: t()
  def new(error, token) do
    %__MODULE__{
      error: error,
      token: token
    }
  end
end
