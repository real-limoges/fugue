defmodule Fugue.Fuzzy.Inference.WireTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.Inference.Wire
  alias Fugue.Menagerie.Mamdani, as: FanDemo

  test "decodes and runs the menagerie fan-demo request, returning the wire response shape" do
    request = FanDemo.request(FanDemo.default_temperature(), FanDemo.default_humidity())
    response = Wire.run_request(request)

    assert Map.has_key?(response, "input_degrees")
    assert Map.has_key?(response, "rule_strengths")
    assert Map.has_key?(response, "output_curves")
    assert Map.has_key?(response, "crisp")

    assert length(response["rule_strengths"]) == 7
    assert %{"fan_speed" => curve} = response["output_curves"]
    assert length(curve) == 200
    assert Enum.all?(curve, fn [x, y] -> is_number(x) and is_number(y) end)

    assert %{"fan_speed" => crisp} = response["crisp"]
    assert crisp >= 0.0 and crisp <= 100.0
  end

  test "a hot, humid room drives the fan crisper toward high than a cold room does" do
    hot = Wire.run_request(FanDemo.request(38.0, 90.0))
    cold = Wire.run_request(FanDemo.request(2.0, 90.0))

    assert hot["crisp"]["fan_speed"] > cold["crisp"]["fan_speed"]
  end
end
