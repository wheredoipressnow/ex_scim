defmodule ExScimClient.Pagination do
  @enforce_keys [:count]
  defstruct [:count, start_index: 1]

  @type t :: %__MODULE__{
          start_index: pos_integer(),
          count: pos_integer()
        }

  def new(count, start_index \\ 1)
      when is_integer(count) and count > 0 and is_integer(start_index) and start_index > 0 do
    %__MODULE__{count: count, start_index: start_index}
  end
end
