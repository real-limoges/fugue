defmodule Fugue.Menagerie.StarsTest do
  use ExUnit.Case, async: true

  alias Fugue.Menagerie.Stars

  test "ships exactly 500 products" do
    assert Stars.count() == 500
    assert length(Stars.all()) == 500
  end

  test "every row has the expected shape and value ranges" do
    for product <- Stars.all() do
      assert is_binary(product.id) and product.id != ""
      assert is_binary(product.name)
      assert is_float(product.avg_rating)
      assert product.avg_rating >= 0.0 and product.avg_rating <= 5.0
      assert is_integer(product.num_reviews)
      assert product.num_reviews >= 0
    end
  end

  test "ids are unique" do
    ids = Stars.all() |> Enum.map(& &1.id)
    assert length(ids) == length(Enum.uniq(ids))
  end
end
