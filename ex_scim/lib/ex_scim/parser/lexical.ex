defmodule ExScim.Parser.Lexical do
  @moduledoc false

  import NimbleParsec

  # Core character sets
  def alpha, do: ascii_string([?a..?z, ?A..?Z], 1)
  def digit, do: ascii_string([?0..?9], 1)
  def hexdig, do: ascii_string([?0..?9, ?A..?F, ?a..?f], 1)

  def wsp_char, do: ascii_char([?\s, ?\t, ?\n, ?\r])
  # def wsp_char, do: ascii_char([32, 9, 10, 13])

  def wsp, do: repeat(wsp_char())

  def quoted_string do
    ignore(string("\""))
    |> repeat(utf8_char(not: ?\"))
    |> ignore(string("\""))
    |> reduce({List, :to_string, []})
  end

  def comp_keyword do
    ascii_string([?a..?z, ?A..?Z], 1)
    |> repeat(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_], 1))
    |> reduce({Enum, :join, [""]})
  end

  def comp_value do
    choice([
      string("false"),
      string("true"),
      string("null"),
      quoted_string(),
      comp_keyword()
    ])
  end
end
