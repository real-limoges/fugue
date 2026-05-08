defmodule FugueWeb.MenagerieLive.AnimatedCard.Slider do
  @moduledoc """
  Declarative slider config for an animated menagerie card. Carries
  everything `FugueWeb.MenagerieLive.AnimatedCard` needs to parse the
  input from a form and render the slider with a display value.

  The card holds a list of `%Slider{}` as `@sliders`; the seam reads
  `key`, `min`, `max`, `cast` for parse, and `label`, `min`, `max`,
  `step`, `format` for render.
  """

  @enforce_keys [:key, :label, :min, :max]
  defstruct [:key, :label, :min, :max, :cast, :format, step: 1]

  @type t :: %__MODULE__{
          key: String.t(),
          label: String.t(),
          min: number(),
          max: number(),
          step: number(),
          cast: (number() -> number()),
          format: (term() -> String.t())
        }

  @doc """
  Builds a `%Slider{}` from a keyword list. `cast` defaults to identity;
  `format` defaults to `default_format/1`.
  """
  def new(opts) do
    opts
    |> Keyword.put_new_lazy(:cast, fn -> &Function.identity/1 end)
    |> Keyword.put_new_lazy(:format, fn -> &__MODULE__.default_format/1 end)
    |> then(&struct!(__MODULE__, &1))
  end

  @doc """
  Default value formatter. Integers print as-is. Floats trim trailing
  zeros but keep one decimal so `1.0` stays `1.0`, not `1`.
  """
  def default_format(v) when is_integer(v), do: Integer.to_string(v)

  def default_format(v) when is_float(v) do
    raw = :erlang.float_to_binary(v, decimals: 4)
    raw |> String.replace(~r/0+$/, "") |> String.replace(~r/\.$/, ".0")
  end

  def default_format(v), do: to_string(v)
end
