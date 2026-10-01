defmodule FugueWeb.FeedControllerTest do
  use FugueWeb.ConnCase

  require Record

  Record.defrecordp(
    :xml_element,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(:xml_text, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  test "GET /feed.xml returns a well-formed RSS 2.0 document", %{conn: conn} do
    conn = get(conn, ~p"/feed.xml")
    assert ["application/rss+xml" <> _] = get_resp_header(conn, "content-type")

    # xmerl raises on malformed XML, so parsing at all is the well-formedness check.
    {doc, _rest} =
      conn |> response(200) |> :binary.bin_to_list() |> :xmerl_scan.string(quiet: true)

    assert xml_element(doc, :name) == :rss
    assert text_at(doc, ~c"/rss/@version") == "2.0"
    assert text_at(doc, ~c"/rss/channel/title") == "realcomplex.systems"

    item_titles = Enum.map(:xmerl_xpath.string(~c"/rss/channel/item/title", doc), &text/1)
    assert item_titles == Enum.map(FugueWeb.Updates.entries(), & &1.title)
  end

  defp text_at(doc, path) do
    case :xmerl_xpath.string(path, doc) do
      [{:xmlAttribute, _, _, _, _, _, _, _, value, _}] -> List.to_string(value)
      [element] -> text(element)
    end
  end

  defp text(element) do
    element
    |> xml_element(:content)
    |> Enum.map_join(&(&1 |> xml_text(:value) |> List.to_string()))
  end
end
