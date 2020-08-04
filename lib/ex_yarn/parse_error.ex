defmodule ExYarn.ParseError do
  alias ExYarn.Token

  @enforce_keys [:error, :token]
  defstruct [:error, :token]

  @type t() :: %__MODULE__{
          error: String.t(),
          token: Token.t() | nil
        }

  @spec new(String.t(), Token.t() | nil) :: t()
  def new(error, token) do
    %__MODULE__{
      error: error,
      token: token
    }
  end
end
