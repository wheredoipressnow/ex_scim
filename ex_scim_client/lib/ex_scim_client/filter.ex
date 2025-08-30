defmodule ExScimClient.Filter do
  @moduledoc """
  DSL for building SCIM filter strings.
  """

  defstruct [:expr]

  def new, do: %__MODULE__{expr: nil}

  def build(%__MODULE__{expr: expression}), do: render(expression)

  # Comparison operator

  def equals(filter, attribute, value), do: put_expression(filter, {:eq, attribute, value})
  def not_equal(filter, attribute, value), do: put_expression(filter, {:ne, attribute, value})
  def contains(filter, attribute, value), do: put_expression(filter, {:co, attribute, value})
  def starts_with(filter, attribute, value), do: put_expression(filter, {:sw, attribute, value})
  def ends_with(filter, attribute, value), do: put_expression(filter, {:ew, attribute, value})
  def greater_than(filter, attribute, value), do: put_expression(filter, {:gt, attribute, value})

  def greater_or_equal(filter, attribute, value),
    do: put_expression(filter, {:ge, attribute, value})

  def less_than(filter, attribute, value), do: put_expression(filter, {:lt, attribute, value})
  def less_or_equal(filter, attribute, value), do: put_expression(filter, {:le, attribute, value})
  def present(filter, attribute, _value), do: put_expression(filter, {:pr, attribute, nil})

  # Logical operator

  def and1(filter1, filter2), do: combine_expressions(:and, filter1, filter2)
  def not1(filter1, filter2), do: combine_expressions(:not, filter1, filter2)
  def or1(filter1, filter2), do: combine_expressions(:or, filter1, filter2)

  # AST

  defp put_expression(%__MODULE__{expr: nil} = _filter, expression) do
    %__MODULE__{expr: expression}
  end

  defp put_expression(%__MODULE__{expr: _} = filter, expression) do
    %__MODULE__{filter | expr: expression}
  end

  defp combine_expressions(op, %__MODULE__{expr: expr1}, %__MODULE__{expr: expr2}) do
    %__MODULE__{expr: {op, expr1, expr2}}
  end

  # Render filter string

  defp render(nil), do: ""
  defp render({:eq, attribute, value}), do: "#{attribute} eq #{value}"
  defp render({:ne, attribute, value}), do: "#{attribute} ne #{value}"
  defp render({:co, attribute, value}), do: "#{attribute} co #{value}"
  defp render({:sw, attribute, value}), do: "#{attribute} sw #{value}"
  defp render({:ew, attribute, value}), do: "#{attribute} ew #{value}"
  defp render({:gt, attribute, value}), do: "#{attribute} gt #{value}"
  defp render({:ge, attribute, value}), do: "#{attribute} ge #{value}"
  defp render({:lt, attribute, value}), do: "#{attribute} lt #{value}"
  defp render({:le, attribute, value}), do: "#{attribute} le #{value}"
  defp render({:pr, attribute, nil}), do: "#{attribute} pr"

  defp render({:and, expr1, expr2}), do: "(#{render(expr1)}) and (#{render(expr2)})"
  defp render({:not, expr1, expr2}), do: "(#{render(expr1)}) not (#{render(expr2)})"
  defp render({:or, expr1, expr2}), do: "(#{render(expr1)}) or (#{render(expr2)})"
end
