defmodule FugueWeb.AmigosLiveTest do
  use FugueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Fugue.Amigos

  test "/amigos opens calm: the spine and nothing else", %{conn: conn} do
    {:ok, view, html} = live(conn, "/amigos")

    assert html =~ "Michael tells Gob he has no friends."
    refute has_element?(view, "#amigos-footnotes")
    refute has_element?(view, "#amigos-ending")

    for layer <- Amigos.layers() do
      refute has_element?(view, "#layer-#{layer.id}"), "#{layer.id} is on the page at beat 1"
    end
  end

  test "each beat puts its layers on the page, and scrolling back takes them off", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")

    render_hook(view, "beat", %{"beat" => 8})

    for id <- ~w(crossed_conversations hog ann gobs_friend surveillance silent_film) do
      assert has_element?(view, "#layer-#{id}"), "#{id} missing at beat 8"
    end

    refute has_element?(view, "#layer-blueprint")

    render_hook(view, "beat", %{"beat" => 3})
    refute has_element?(view, "#layer-ann"), "scrolling back up left a later layer on the page"
    assert has_element?(view, "#layer-surveillance")
  end

  test "the crowded zones arrive one layer at a time", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")

    render_hook(view, "beat", %{"beat" => 4})
    assert has_element?(view, "#layer-silent_film")
    refute has_element?(view, "#layer-tobias_blue")

    render_hook(view, "beat", %{"beat" => 5})
    assert has_element?(view, "#layer-tobias_blue")

    render_hook(view, "beat", %{"beat" => 15})
    assert has_element?(view, "#layer-friends_titles")
    refute has_element?(view, "#layer-george_sr")
  end

  test "arrows wait for their beats", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")
    callbacks = Amigos.arrows_from(:callback)
    foreshadowing = Amigos.arrows_from(:foreshadowing)

    render_hook(view, "beat", %{"beat" => callbacks - 1})
    refute has_element?(view, "#amigos-callback li")

    render_hook(view, "beat", %{"beat" => callbacks})
    assert has_element?(view, "#amigos-callback li", ~s(S1E19 "Best Man for the Gob"))
    refute has_element?(view, "#amigos-foreshadowing li")

    render_hook(view, "beat", %{"beat" => foreshadowing - 1})
    refute has_element?(view, "#amigos-foreshadowing li")

    render_hook(view, "beat", %{"beat" => Amigos.last_beat()})
    assert has_element?(view, "#amigos-foreshadowing li", ~s(S2E11 "Out on a Limb"))
  end

  test "every layer is on the page by the last beat", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")
    render_hook(view, "beat", %{"beat" => Amigos.last_beat()})

    for layer <- Amigos.layers() do
      assert has_element?(view, "#layer-#{layer.id}"), "#{layer.id} missing at the last beat"
    end

    refute has_element?(view, "#amigos-ending")
  end

  test "the ending's counter is one short, and the footnote says so", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")
    render_hook(view, "beat", %{"beat" => Amigos.last_beat() + 1})

    assert has_element?(view, "#amigos-counter", "only #{Amigos.counted_count()} of them")
    refute has_element?(view, "#amigos-counter", "#{length(Amigos.layers())}")
    assert has_element?(view, "#amigos-late-footnote", "That count is wrong.")

    assert has_element?(view, "#layer-ann"),
           "Ann has to be on the page the counter leaves her out of"
  end

  test "beats outside the page are clamped", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")

    render_hook(view, "beat", %{"beat" => 99})
    assert has_element?(view, "#amigos-ending")
  end

  test "reduced motion shows the finished page, still, and can build it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")
    render_hook(view, "reduced_motion", %{})

    refute has_element?(view, "#amigos-track")
    assert has_element?(view, "#amigos-counter")
    assert has_element?(view, "#amigos-late-footnote")

    for layer <- Amigos.layers() do
      assert has_element?(view, "#layer-#{layer.id}"), "#{layer.id} missing from the static page"
    end

    view |> element("#amigos-watch-build") |> render_click()

    assert has_element?(view, "#amigos-track")
    refute has_element?(view, "#amigos-ending")
    refute has_element?(view, "#layer-ann")
  end

  test "the clutter piles up too: every internal connection gets scrawled", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/amigos")
    stamps = "#amigos-clutter .amigos-stamp"

    render_hook(view, "beat", %{"beat" => 7})
    refute has_element?(view, stamps)

    render_hook(view, "beat", %{"beat" => 8})
    assert view |> element(stamps) |> render() =~ "S1E19"

    render_hook(view, "beat", %{"beat" => Amigos.last_beat()})

    for layer <- Amigos.layers(), connection <- Amigos.connections(layer, :internal) do
      assert has_element?(view, "#amigos-clutter .amigos-scrawl", connection.note),
             "#{layer.id}'s internal connection is not scrawled"
    end
  end
end
