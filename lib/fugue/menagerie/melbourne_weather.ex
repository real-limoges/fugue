defmodule Fugue.Menagerie.MelbourneWeather do
  @moduledoc """
  Compile-time bundled Melbourne Airport (GHCN-D station `ASN00086282`)
  daily weather, sourced from NCEI (temps + precip) and Open-Meteo ERA5
  (wind). The CSV at `priv/static/menagerie/melbourne_weather.csv` is
  checked in; `@external_resource` makes this module recompile when it
  changes.
  """

  @csv_path "priv/static/menagerie/melbourne_weather.csv"
  @external_resource @csv_path

  @rows @csv_path
        |> File.read!()
        |> String.split("\n", trim: true)
        |> tl()
        |> Enum.map(fn line ->
          [_station, date, prcp, tavg, tmax, tmin, wspd_max, wspd_mean] =
            line |> String.split(",") |> Enum.map(&String.trim(&1, "\""))

          to_float = fn
            "" ->
              nil

            s ->
              case Float.parse(s) do
                {v, _} -> v
                :error -> nil
              end
          end

          %{
            date: date,
            prcp: to_float.(prcp),
            tavg: to_float.(tavg),
            tmax: to_float.(tmax),
            tmin: to_float.(tmin),
            wspd_max: to_float.(wspd_max),
            wspd_mean: to_float.(wspd_mean)
          }
        end)

  if @rows == [], do: raise(CompileError, description: "#{@csv_path} has no data rows")

  @type row :: %{
          date: String.t(),
          prcp: float() | nil,
          tavg: float() | nil,
          tmax: float() | nil,
          tmin: float() | nil,
          wspd_max: float() | nil,
          wspd_mean: float() | nil
        }

  @doc "All parsed rows in date order."
  @spec rows() :: [row(), ...]
  def rows, do: @rows

  @doc """
  First and last ISO-8601 dates in the bundled dataset. Never empty: the
  module refuses to compile against a CSV with no data rows.
  """
  @spec date_range() :: {String.t(), String.t()}
  def date_range, do: {hd(@rows).date, List.last(@rows).date}

  @doc "Row count."
  @spec count() :: pos_integer()
  def count, do: length(@rows)
end
