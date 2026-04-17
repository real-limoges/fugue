defmodule Fugue.Menagerie.Mamdani do
  @moduledoc """
  Fan-controller Mamdani fixture for the /menagerie playground. Pure: given
  crisp temperature and humidity, produces the wire-format MamdaniRequest
  that Ish's `POST /inference/mamdani` expects. Two inputs with three terms
  each, one four-term output, and seven rules covering the 3x3 grid.
  """

  @temperature_var %{
    "name" => "temperature",
    "bounds" => [0.0, 40.0],
    "terms" => [
      %{"name" => "cold", "params" => [0.0, 0.0, 26.0]},
      %{"name" => "warm", "params" => [6.0, 22.0, 38.0]},
      %{"name" => "hot", "params" => [18.0, 40.0, 40.0]}
    ]
  }

  @humidity_var %{
    "name" => "humidity",
    "bounds" => [0.0, 100.0],
    "terms" => [
      %{"name" => "dry", "params" => [0.0, 0.0, 60.0]},
      %{"name" => "comfortable", "params" => [15.0, 50.0, 85.0]},
      %{"name" => "humid", "params" => [40.0, 100.0, 100.0]}
    ]
  }

  @fan_speed_var %{
    "name" => "fan_speed",
    "bounds" => [0.0, 100.0],
    "terms" => [
      %{"name" => "off", "params" => [0.0, 0.0, 20.0]},
      %{"name" => "low", "params" => [10.0, 30.0, 50.0]},
      %{"name" => "medium", "params" => [35.0, 55.0, 75.0]},
      %{"name" => "high", "params" => [60.0, 100.0, 100.0]}
    ]
  }

  @rules [
    {"IF temperature cold THEN fan off",
     %{
       "if" => [%{"var" => "temperature", "term" => "cold"}],
       "then" => [%{"var" => "fan_speed", "term" => "off"}]
     }},
    {"IF temperature warm AND humidity dry THEN fan low",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "warm"},
         %{"var" => "humidity", "term" => "dry"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "low"}]
     }},
    {"IF temperature warm AND humidity comfortable THEN fan medium",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "warm"},
         %{"var" => "humidity", "term" => "comfortable"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "medium"}]
     }},
    {"IF temperature warm AND humidity humid THEN fan medium",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "warm"},
         %{"var" => "humidity", "term" => "humid"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "medium"}]
     }},
    {"IF temperature hot AND humidity dry THEN fan medium",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "hot"},
         %{"var" => "humidity", "term" => "dry"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "medium"}]
     }},
    {"IF temperature hot AND humidity comfortable THEN fan high",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "hot"},
         %{"var" => "humidity", "term" => "comfortable"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "high"}]
     }},
    {"IF temperature hot AND humidity humid THEN fan high",
     %{
       "if" => [
         %{"var" => "temperature", "term" => "hot"},
         %{"var" => "humidity", "term" => "humid"}
       ],
       "then" => [%{"var" => "fan_speed", "term" => "high"}]
     }}
  ]

  @default_temperature 22.0
  @default_humidity 50.0

  def default_temperature, do: @default_temperature
  def default_humidity, do: @default_humidity

  def mfs do
    %{
      "inputs" => [@temperature_var, @humidity_var],
      "outputs" => [@fan_speed_var]
    }
  end

  def rule_descriptions, do: Enum.map(@rules, fn {desc, _} -> desc end)

  @doc """
  Each rule's descriptive text paired with the name of its single fan_speed
  consequent term. Used to color rule bars and per-rule clipped shapes in the
  playground viz by the consequent they vote for.
  """
  def rule_summaries do
    Enum.map(@rules, fn {desc, %{"then" => [%{"term" => term} | _]}} ->
      %{text: desc, output_term: term}
    end)
  end

  def request(temperature, humidity) do
    %{
      "mfs" => mfs(),
      "rules" => Enum.map(@rules, fn {_, rule} -> rule end),
      "values" => %{
        "temperature" => temperature * 1.0,
        "humidity" => humidity * 1.0
      }
    }
  end
end
