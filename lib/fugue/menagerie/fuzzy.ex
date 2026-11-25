defmodule Fugue.Menagerie.Fuzzy do
  @moduledoc """
  Pure triangular membership functions for the menagerie fuzzy-math experiments.
  No state, no I/O. Just math that the LiveView re-runs when parameters change.
  """

  alias Fugue.Fuzzy.Membership
  alias Fugue.Menagerie.MelbourneWeather

  defmodule MF do
    @moduledoc """
    One triangular membership function: zero at `a` and `c`, one at the
    peak `b`. `name` is the fuzzy set's label and `color` its CSS color (a `var(--menagerie-temp-*)` reference).
    """

    @enforce_keys [:name, :color, :a, :b, :c]
    defstruct [:name, :color, :a, :b, :c]

    @type t :: %__MODULE__{
            name: String.t(),
            color: String.t(),
            a: number(),
            b: number(),
            c: number()
          }
  end

  @typedoc "Normalized membership per fuzzy set name."
  @type memberships :: %{String.t() => float()}

  @typedoc "One day's memberships, keyed by its ISO-8601 date."
  @type band_row :: %{date: String.t(), memberships: memberships()}

  # {name, default_peak_celsius, CSS color}. Palette picked for maximum hue
  # contrast between adjacent bands rather than a literal temperature gradient
  # so stacked bands stay distinguishable without relying on red/green. The
  # per-theme values live in assets/css/palettes/menagerie.css.
  @base_mfs [
    {"cold", 10.0, "var(--menagerie-temp-cold)"},
    {"cool", 17.0, "var(--menagerie-temp-cool)"},
    {"mild", 24.0, "var(--menagerie-temp-mild)"},
    {"warm", 31.0, "var(--menagerie-temp-warm)"},
    {"hot", 38.0, "var(--menagerie-temp-hot)"}
  ]

  @default_half_width 7.0

  @doc """
  Build the five temperature MFs. `center_offset` shifts every peak along the
  temperature axis; `spread` multiplies the triangle half-width so adjacent
  sets overlap more or less.
  """
  @spec build_mfs(number(), number()) :: [MF.t(), ...]
  def build_mfs(center_offset, spread)
      when is_number(center_offset) and is_number(spread) do
    half = @default_half_width * spread

    for {name, center, color} <- @base_mfs do
      peak = center + center_offset

      %MF{
        name: name,
        color: color,
        a: peak - half,
        b: peak,
        c: peak + half
      }
    end
  end

  @doc """
  Triangular membership of `x`: `Fugue.Fuzzy.Membership.triangular/3`,
  applied. A missing reading never gets here; `bands/2` scores it 0.
  """
  @spec triangular(number(), number(), number(), number()) :: float()
  def triangular(x, a, b, c), do: Membership.triangular(a, b, c).(x)

  @doc """
  Sample a single MF across `[lo, hi]` at `steps + 1` evenly-spaced x values.
  Returns a list of `[x, y]` pairs suitable for d3 line/area generators on
  the client; clients don't re-derive triangles, they just render.
  """
  @spec sample_shape(MF.t(), number(), number(), pos_integer()) :: [[float()], ...]
  def sample_shape(mf, lo, hi, steps \\ 80)
      when is_number(lo) and is_number(hi) and is_integer(steps) and steps > 0 do
    span = hi - lo

    for i <- 0..steps do
      x = lo + span * i / steps
      [x, triangular(x, mf.a, mf.b, mf.c)]
    end
  end

  @doc """
  Normalized memberships for one value across all MFs. Normalization makes
  the stacked area chart fill the full height even when raw memberships
  don't sum to 1 (e.g. when spread is narrow).
  """
  @spec memberships(number(), [MF.t()]) :: memberships()
  def memberships(x, mfs) do
    raw = Enum.map(mfs, fn mf -> {mf.name, triangular(x, mf.a, mf.b, mf.c)} end)
    total = Enum.reduce(raw, 0.0, fn {_, v}, acc -> acc + v end)

    if total > 0 do
      Map.new(raw, fn {name, v} -> {name, v / total} end)
    else
      Map.new(raw, fn {name, _} -> {name, 0.0} end)
    end
  end

  @doc """
  For every weather row, compute fuzzy memberships on its TMAX value.
  Rows without a TMAX get all zeros (rendered as a gap in the chart).
  """
  @spec bands([MelbourneWeather.row()], [MF.t()]) :: [band_row()]
  def bands(rows, mfs) do
    zero = Map.new(mfs, fn mf -> {mf.name, 0.0} end)

    Enum.map(rows, fn row ->
      mems =
        if is_nil(row.tmax) do
          zero
        else
          memberships(row.tmax, mfs)
        end

      %{date: row.date, memberships: mems}
    end)
  end
end
