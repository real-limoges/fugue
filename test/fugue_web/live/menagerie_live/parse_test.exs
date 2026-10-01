defmodule FugueWeb.MenagerieLive.ParseTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FugueWeb.MenagerieLive.Parse

  describe "parse_float/2" do
    test "reads a slider's string value" do
      assert Parse.parse_float("22.5", 0.0) == 22.5
      assert Parse.parse_float("40", 0.0) == 40.0
    end

    test "falls back to the default when the string is not a number" do
      assert Parse.parse_float("", 7.0) == 7.0
      assert Parse.parse_float("warm", 7.0) == 7.0
    end

    property "reads back what format_number/2 wrote, to its precision" do
      check all(n <- float(min: -100.0, max: 100.0), decimals <- integer(0..3)) do
        shown = Parse.format_number(n, decimals)
        assert_in_delta Parse.parse_float(shown, nil), n, 0.5 * 10 ** -decimals + 1.0e-9
      end
    end
  end

  describe "format_number/2" do
    test "pads or rounds to the requested decimals" do
      assert Parse.format_number(3, 1) == "3.0"
      assert Parse.format_number(2.345, 2) == "2.35"
      assert Parse.format_number(40.0, 0) == "40"
    end
  end
end
