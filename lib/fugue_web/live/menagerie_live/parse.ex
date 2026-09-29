defmodule FugueWeb.MenagerieLive.Parse do
  @moduledoc """
  Shared slider-input helpers for the non-animated menagerie cards
  (`fuzzy`, `mamdani`). The animated cards route parameter parsing through
  `FugueWeb.MenagerieLive.AnimatedCard` instead.
  """

  @doc "Parse a slider's string value to a float, falling back to `default`."
  def parse_float(str, default) do
    case Float.parse(str) do
      {v, _} -> v
      :error -> default
    end
  end

  @doc "Format a number for display with a fixed number of decimals."
  def format_number(n, decimals) when is_number(n) do
    :erlang.float_to_binary(n / 1, decimals: decimals)
  end
end
