defmodule Fugue.Color.ConesTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.Cones

  test "tabulated bounds match the published Stockman & Sharpe range" do
    assert Cones.lambda_min() == 390
    assert Cones.lambda_max() == 780
  end

  test "every cone peaks at 1.0 somewhere in the visible range" do
    for cone <- [:l, :m, :s] do
      peak =
        Cones.lambda_min()..Cones.lambda_max()
        |> Enum.map(&Cones.response(cone, &1))
        |> Enum.max()

      assert_in_delta(peak, 1.0, 1.0e-6)
    end
  end

  test "cone peaks lie in the textbook neighborhoods" do
    {peak_l, _} = peak_for(:l)
    {peak_m, _} = peak_for(:m)
    {peak_s, _} = peak_for(:s)

    # L ~ 558-565, M ~ 530-545, S ~ 420-440 nm.
    assert peak_l in 555..570
    assert peak_m in 525..550
    assert peak_s in 415..445
  end

  test "S cone is exactly 0 past ~667 nm (S&S did not measure the tail)" do
    assert Cones.response(:s, 700) == 0.0
    assert Cones.response(:s, 750) == 0.0
  end

  test "values clamp at the boundaries" do
    assert Cones.response(:l, 200) == Cones.response(:l, 390)
    assert Cones.response(:l, 1000) == Cones.response(:l, 780)
  end

  test "interpolation lies between the bracketing samples" do
    a = Cones.response(:m, 500)
    mid = Cones.response(:m, 500.5)
    b = Cones.response(:m, 501)

    lo = min(a, b)
    hi = max(a, b)
    assert mid >= lo and mid <= hi
  end

  test "raises for unknown cone atoms" do
    # Called through apply/3 on purpose. A literal `Cones.response(:x, 500)`
    # lets the compiler see the guard can never match and warn about it, which
    # is exactly the case under test; apply/3 keeps the assertion honest and
    # the build quiet.
    assert_raise FunctionClauseError, fn -> apply(Cones, :response, [:x, 500]) end
  end

  defp peak_for(cone) do
    Cones.lambda_min()..Cones.lambda_max()
    |> Enum.map(fn l -> {l, Cones.response(cone, l)} end)
    |> Enum.max_by(fn {_, v} -> v end)
  end
end
