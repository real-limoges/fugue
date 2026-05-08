defmodule FugueWeb.MenagerieLive.AnimatedCardTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  describe "Slider.new/1" do
    test "fills cast and format with sane defaults" do
      slider = Slider.new(key: "x", label: "X", min: 0, max: 10)

      assert slider.key == "x"
      assert slider.label == "X"
      assert slider.min == 0
      assert slider.max == 10
      assert slider.step == 1
      assert is_function(slider.cast, 1)
      assert is_function(slider.format, 1)
      assert slider.cast.(3.5) == 3.5
    end

    test "honors a custom cast" do
      slider = Slider.new(key: "n", label: "N", min: 0, max: 10, cast: &trunc/1)
      assert slider.cast.(3.7) == 3
    end

    test "honors a custom format" do
      slider = Slider.new(key: "x", label: "X", min: 0, max: 10, format: fn v -> "[#{v}]" end)
      assert slider.format.(5) == "[5]"
    end

    test "raises when required keys are missing" do
      assert_raise ArgumentError, fn -> Slider.new(label: "X", min: 0, max: 10) end
    end
  end

  describe "Slider.default_format/1" do
    test "renders integers as-is" do
      assert Slider.default_format(1500) == "1500"
      assert Slider.default_format(0) == "0"
    end

    test "trims trailing zeros from floats but keeps one decimal" do
      assert Slider.default_format(1.0) == "1.0"
      assert Slider.default_format(0.5) == "0.5"
      assert Slider.default_format(0.005) == "0.005"
    end

    test "falls back to to_string for other values" do
      assert Slider.default_format("center") == "center"
    end
  end

  describe "parse_params/3" do
    setup do
      sliders = [
        Slider.new(key: "speed", label: "Speed", min: 1, max: 200, cast: &trunc/1),
        Slider.new(key: "decay", label: "Decay", min: 0.0, max: 1.0)
      ]

      {:ok, sliders: sliders, current: %{"speed" => 10, "decay" => 0.5}}
    end

    test "parses, clamps, and casts each present slider", %{sliders: sliders, current: current} do
      form = %{"speed" => "150", "decay" => "0.8"}

      assert AnimatedCard.parse_params(form, current, sliders) == %{
               "speed" => 150,
               "decay" => 0.8
             }
    end

    test "clamps values that exceed max", %{sliders: sliders, current: current} do
      form = %{"speed" => "9999"}

      assert AnimatedCard.parse_params(form, current, sliders) == %{
               "speed" => 200,
               "decay" => 0.5
             }
    end

    test "clamps values below min", %{sliders: sliders, current: current} do
      form = %{"speed" => "-5"}
      assert AnimatedCard.parse_params(form, current, sliders) == %{"speed" => 1, "decay" => 0.5}
    end

    test "applies cast after clamp so int sliders stay int", %{sliders: sliders, current: current} do
      form = %{"speed" => "42.9"}
      result = AnimatedCard.parse_params(form, current, sliders)
      assert result["speed"] == 42
      assert is_integer(result["speed"])
    end

    test "falls back to current value on garbage input", %{sliders: sliders, current: current} do
      form = %{"speed" => "not-a-number"}
      assert AnimatedCard.parse_params(form, current, sliders) == current
    end

    test "ignores form keys that aren't in the slider list", %{sliders: sliders, current: current} do
      form = %{"speed" => "20", "stranger" => "999"}
      result = AnimatedCard.parse_params(form, current, sliders)
      refute Map.has_key?(result, "stranger")
    end

    test "leaves params untouched for sliders absent from the form", %{
      sliders: sliders,
      current: current
    } do
      form = %{"speed" => "20"}
      assert AnimatedCard.parse_params(form, current, sliders) == %{"speed" => 20, "decay" => 0.5}
    end

    test "returns the same map shape when the form is empty", %{
      sliders: sliders,
      current: current
    } do
      assert AnimatedCard.parse_params(%{}, current, sliders) == current
    end
  end

  describe "slider_grid/1" do
    import Phoenix.LiveViewTest

    test "renders a labelled range input per slider with the formatted value" do
      sliders = [
        Slider.new(key: "speed", label: "Speed", min: 1, max: 200, cast: &trunc/1),
        Slider.new(
          key: "decay",
          label: "Decay",
          min: 0.0,
          max: 1.0,
          format: fn v -> "#{v}x" end
        )
      ]

      params = %{"speed" => 42, "decay" => 0.7}

      html =
        render_component(&AnimatedCard.slider_grid/1, sliders: sliders, params: params)

      assert html =~ "Speed"
      assert html =~ "Decay"
      assert html =~ ~s(name="speed")
      assert html =~ ~s(name="decay")
      assert html =~ ~s(value="42")
      assert html =~ ~s(value="0.7")
      assert html =~ "42"
      assert html =~ "0.7x"
      assert html =~ ~s(phx-change="update_params")
    end
  end
end
