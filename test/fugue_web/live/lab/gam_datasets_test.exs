defmodule FugueWeb.LabLive.GamDatasetsTest do
  use ExUnit.Case, async: true

  alias FugueWeb.LabLive.GamDatasets

  test "ships four datasets" do
    assert length(GamDatasets.all()) == 4
  end

  test "every dataset has the required UI fields" do
    for ds <- GamDatasets.all() do
      assert is_binary(ds.id) and ds.id != ""
      assert is_binary(ds.label)
      assert is_binary(ds.title)
      assert is_binary(ds.blurb)
      assert is_list(ds.layers) and length(ds.layers) > 0
      assert is_list(ds.captions) and length(ds.captions) == length(ds.layers)
    end
  end

  test "ids are unique" do
    ids = GamDatasets.ids()
    assert length(ids) == length(Enum.uniq(ids))
    assert ids == Enum.map(GamDatasets.all(), & &1.id)
  end

  test "every dataset exposes the three layer ids the LiveView toggles" do
    for ds <- GamDatasets.all() do
      ids = Enum.map(ds.layers, & &1.id)
      assert Enum.sort(ids) == ~w(gam gamlss linear)
    end
  end

  test "fetch/1 returns {:ok, ds} for known ids and :error otherwise" do
    for id <- GamDatasets.ids() do
      assert {:ok, %{id: ^id}} = GamDatasets.fetch(id)
    end

    assert GamDatasets.fetch("does_not_exist") == :error
  end

  test "captions reference allowed accent atoms" do
    allowed = ~w(white_dash white_dim gray primary)a

    for ds <- GamDatasets.all(),
        cap <- ds.captions do
      assert cap.accent in allowed
      assert is_binary(cap.glyph)
      assert is_binary(cap.text)
    end
  end
end
