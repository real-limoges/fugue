defmodule Fugue.AmigosTest do
  @moduledoc """
  Pins the premises the `/amigos` ending rests on: the page holds every
  layer, and the counter admits to all but one of them, Ann's.
  """
  use ExUnit.Case, async: true

  alias Fugue.Amigos

  test "exactly one layer is uncounted, and it is Ann's" do
    assert [%{id: :ann}] = Enum.reject(Amigos.layers(), & &1.counted)
  end

  test "the counter is one short of the page" do
    assert Amigos.counted_count() == length(Amigos.layers()) - 1
  end

  test "Ann arrives in beat 8, next to the layers that name her" do
    assert Amigos.layer!(:ann).beats == [8]

    assert for(layer <- Amigos.layers(), 8 in layer.beats, do: layer.id) == [
             :crossed_conversations,
             :hog,
             :ann
           ]
  end

  test "every layer appears on at least one beat, and none before beat 1" do
    for layer <- Amigos.layers() do
      assert layer.beats != [], "#{layer.id} has no beats"
      assert Enum.all?(layer.beats, &(&1 >= 1)), "#{layer.id} has a beat before 1"
    end
  end

  test "every beat adds or repeats at least one layer" do
    for beat <- 1..Amigos.last_beat() do
      assert Enum.any?(Amigos.layers(), &(beat in &1.beats)), "beat #{beat} has no layers"
    end
  end

  test "after the footnotes, the layers pile up one per beat, except Ann's" do
    ann = Amigos.first_beat(Amigos.layer!(:ann))

    for beat <- 4..Amigos.last_beat(), beat != ann do
      arriving = Enum.filter(Amigos.layers(), &(Amigos.first_beat(&1) == beat))
      assert length(arriving) == 1, "beat #{beat} adds #{length(arriving)} layers"
    end
  end

  test "every layer is on the page by the last beat" do
    assert Amigos.revealed_by(Amigos.last_beat()) == Amigos.layers()
  end

  test "ids are unique" do
    ids = Enum.map(Amigos.layers(), & &1.id)
    assert ids == Enum.uniq(ids)
  end

  test "every connection points one of three ways" do
    for layer <- Amigos.layers(), connection <- layer.connections do
      assert connection.direction in [:callback, :foreshadowing, :internal]
    end
  end

  test "internal connections have no target episode, and outward ones do" do
    for layer <- Amigos.layers(), connection <- layer.connections do
      if connection.direction == :internal do
        assert is_nil(connection.target), "#{layer.id} has an internal connection with a target"
      else
        assert is_binary(connection.target),
               "#{layer.id} has an outward connection with no target"
      end
    end
  end

  test "the callback margin fills before the foreshadowing one" do
    assert Amigos.arrows_from(:callback) < Amigos.arrows_from(:foreshadowing)
  end

  test "layer!/1 raises on an unknown id" do
    assert_raise ArgumentError, fn -> Amigos.layer!(:egg) end
  end
end
