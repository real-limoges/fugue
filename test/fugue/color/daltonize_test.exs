defmodule Fugue.Color.DaltonizeTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.Daltonize

  test "returns a normalized 7-character hex" do
    out = Daltonize.protan_hex("#cc3333")
    assert String.match?(out, ~r/^#[0-9a-f]{6}$/)
  end

  test "achromatic input is approximately preserved" do
    # Pure greys are unchanged by any LMS-cone-deficiency simulation.
    for grey <- ~w(#000000 #404040 #808080 #c0c0c0 #ffffff) do
      out = Daltonize.protan_hex(grey)
      assert close?(grey, out, 4)
    end
  end

  test "pure red collapses dramatically under protanopia" do
    # Protan signature: pure red loses most of its R channel.
    {r, _g, b} = parse(Daltonize.protan_hex("#ff0000"))
    assert r < 200
    assert b < 60
  end

  test "pure green stays bright in the green channel" do
    {_r, g, b} = parse(Daltonize.protan_hex("#00ff00"))
    assert g > 150
    assert b < 60
  end

  test "blue is largely preserved" do
    {r, _g, b} = parse(Daltonize.protan_hex("#0000ff"))
    assert b > 200
    assert r < 60
  end

  defp parse("#" <> <<r1, r2, g1, g2, b1, b2>>) do
    {String.to_integer(<<r1, r2>>, 16), String.to_integer(<<g1, g2>>, 16),
     String.to_integer(<<b1, b2>>, 16)}
  end

  defp close?(a, b, tol) do
    {r1, g1, b1} = parse(a)
    {r2, g2, b2} = parse(b)
    abs(r1 - r2) <= tol and abs(g1 - g2) <= tol and abs(b1 - b2) <= tol
  end
end
