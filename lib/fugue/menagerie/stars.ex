defmodule Fugue.Menagerie.Stars do
  @moduledoc """
  Compile-time bundled seed data for the star-ratings exhibit: why a
  4.9-star / 15-review product can rank below a 4.6-star / 950-review
  product once sample size is accounted for.

  The 500 rows in `priv/static/menagerie/stars.csv` are a stratified sample
  of real `(avg_rating, num_reviews)` pairs drawn from the McAuley Amazon
  Reviews 2023 Electronics metadata (1.61M products). Product names are
  synthetic generics; all Amazon identifiers are stripped. Strata
  over-weight both tails (very few reviews and very many) so the ranking
  contrast across methods is pedagogically dramatic.
  """

  @csv_path "priv/static/menagerie/stars.csv"
  @external_resource @csv_path

  @products @csv_path
            |> File.read!()
            |> String.split("\n", trim: true)
            |> tl()
            |> Enum.map(fn line ->
              [id, name, avg_rating, num_reviews] = String.split(line, ",")

              %{
                id: id,
                name: name,
                avg_rating: String.to_float(avg_rating),
                num_reviews: String.to_integer(num_reviews)
              }
            end)

  @doc "All 500 products in load order."
  def all, do: @products

  @doc "Row count."
  def count, do: length(@products)
end
