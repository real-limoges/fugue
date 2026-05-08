defmodule Fugue.Menagerie.MelbourneWeatherTest do
  use ExUnit.Case, async: true

  alias Fugue.Menagerie.MelbourneWeather

  test "rows/0 returns a non-empty list of date-keyed maps" do
    rows = MelbourneWeather.rows()
    assert length(rows) > 0

    sample = hd(rows)
    assert is_binary(sample.date)
    assert Map.has_key?(sample, :prcp)
    assert Map.has_key?(sample, :tavg)
    assert Map.has_key?(sample, :tmax)
    assert Map.has_key?(sample, :tmin)
    assert Map.has_key?(sample, :wspd_max)
    assert Map.has_key?(sample, :wspd_mean)
  end

  test "rows are in chronological order" do
    dates = MelbourneWeather.rows() |> Enum.map(& &1.date)
    assert dates == Enum.sort(dates)
  end

  test "count/0 matches rows length" do
    assert MelbourneWeather.count() == length(MelbourneWeather.rows())
  end

  test "date_range/0 returns the bounding pair" do
    {first, last} = MelbourneWeather.date_range()
    rows = MelbourneWeather.rows()
    assert first == hd(rows).date
    assert last == List.last(rows).date
  end

  test "numeric fields are floats or nil" do
    for row <- Enum.take(MelbourneWeather.rows(), 50),
        field <- [:prcp, :tavg, :tmax, :tmin, :wspd_max, :wspd_mean] do
      v = Map.fetch!(row, field)
      assert is_nil(v) or is_float(v)
    end
  end
end
