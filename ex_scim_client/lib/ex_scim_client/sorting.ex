defmodule ExScimClient.Sorting do
  @enforce_keys [:by]
  defstruct [:by, order: :asc]

  @type t :: %__MODULE__{
          by: String.t(),
          order: :asc | :desc
        }

  def new(by, order \\ :asc) when is_binary(by) and order in [:asc, :desc] do
    %__MODULE__{by: by, order: order}
  end
end
