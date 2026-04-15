defmodule Fugue.Sandbox.MamdaniTest do
  use ExUnit.Case, async: true

  alias Fugue.Sandbox.Mamdani

  describe "defaults" do
    test "default_temperature is a Celsius value inside the fuzzifier bounds" do
      assert Mamdani.default_temperature() == 22.0
    end

    test "default_humidity is a percentage inside the fuzzifier bounds" do
      assert Mamdani.default_humidity() == 50.0
    end
  end

  describe "mfs/0" do
    test "exposes two inputs (temperature, humidity) and one output (fan_speed)" do
      %{"inputs" => inputs, "outputs" => outputs} = Mamdani.mfs()

      assert Enum.map(inputs, & &1["name"]) == ~w(temperature humidity)
      assert Enum.map(outputs, & &1["name"]) == ~w(fan_speed)
    end

    test "every input has three terms matching the fan-controller story" do
      %{"inputs" => [temp, hum]} = Mamdani.mfs()
      assert Enum.map(temp["terms"], & &1["name"]) == ~w(cold warm hot)
      assert Enum.map(hum["terms"], & &1["name"]) == ~w(dry comfortable humid)
    end

    test "fan_speed output has four terms in ascending order" do
      %{"outputs" => [fan]} = Mamdani.mfs()
      assert Enum.map(fan["terms"], & &1["name"]) == ~w(off low medium high)
    end

    test "every term carries triangular params as a three-number list" do
      %{"inputs" => inputs, "outputs" => outputs} = Mamdani.mfs()

      (inputs ++ outputs)
      |> Enum.flat_map(& &1["terms"])
      |> Enum.each(fn term ->
        [a, b, c] = term["params"]
        assert is_number(a) and is_number(b) and is_number(c)
        assert a <= b and b <= c
      end)
    end
  end

  describe "rules" do
    test "rule_descriptions/0 returns seven human-readable strings" do
      descriptions = Mamdani.rule_descriptions()

      assert length(descriptions) == 7
      assert Enum.all?(descriptions, &is_binary/1)
      assert Enum.all?(descriptions, &String.starts_with?(&1, "IF "))
    end

    test "rule_summaries/0 pairs each rule with its fan_speed consequent" do
      summaries = Mamdani.rule_summaries()

      assert length(summaries) == 7
      assert Enum.all?(summaries, fn s -> is_binary(s.text) and is_binary(s.output_term) end)

      terms = Enum.map(summaries, & &1.output_term)
      assert Enum.all?(terms, &(&1 in ~w(off low medium high)))
    end

    test "rule order is stable (viz colors depend on it)" do
      assert Enum.map(Mamdani.rule_summaries(), & &1.output_term) ==
               ~w(off low medium medium medium high high)
    end
  end

  describe "request/2" do
    test "wraps inputs in the wire shape Ish /inference/mamdani expects" do
      req = Mamdani.request(22.0, 50.0)

      assert %{"mfs" => _, "rules" => rules, "values" => values} = req
      assert length(rules) == 7
      assert values == %{"temperature" => 22.0, "humidity" => 50.0}
    end

    test "coerces integer inputs to floats" do
      req = Mamdani.request(22, 50)
      assert req["values"] == %{"temperature" => 22.0, "humidity" => 50.0}
    end

    test "rules are plain maps without the descriptive text" do
      %{"rules" => rules} = Mamdani.request(22.0, 50.0)

      Enum.each(rules, fn rule ->
        assert Map.keys(rule) |> Enum.sort() == ~w(if then)
        refute Map.has_key?(rule, "text")
      end)
    end

    test "each rule's consequent is a single fan_speed term" do
      %{"rules" => rules} = Mamdani.request(22.0, 50.0)

      Enum.each(rules, fn %{"then" => [%{"var" => var, "term" => term}]} ->
        assert var == "fan_speed"
        assert term in ~w(off low medium high)
      end)
    end
  end
end
