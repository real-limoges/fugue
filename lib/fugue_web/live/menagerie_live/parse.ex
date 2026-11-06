defmodule FugueWeb.MenagerieLive.Parse do
  @moduledoc """
  Shared slider-input helpers for the non-animated menagerie cards
  (`fuzzy`, `mamdani`). The animated cards route parameter parsing through
  `FugueWeb.MenagerieLive.AnimatedCard` instead.
  """

  @doc "Parse a slider's string value to a float, falling back to `default`."
  @spec parse_float(String.t(), default) :: float() | default when default: number()
  def parse_float(str, default) do
    case Float.parse(str) do
      {v, _} -> v
      :error -> default
    end
  end

  @doc "Format a number for display with a fixed number of decimals."
  @spec format_number(number(), non_neg_integer()) :: String.t()
  def format_number(n, decimals) when is_number(n) do
    :erlang.float_to_binary(n / 1, decimals: decimals)
  end
end
