defmodule Fugue.Menagerie.QuantumStatsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Fugue.Menagerie.QuantumStats

  property "every statistics holds exactly the particles it was given" do
    check all(
            log_t <- StreamData.float(min: -1.3, max: 1.3),
            n <- StreamData.integer(3..25)
          ) do
      t = :math.pow(10, log_t)

      for {kind, occ} <- QuantumStats.curves(t, n) do
        assert_in_delta Enum.sum(occ), n, 1.0e-6 * n, "#{kind} at kT=#{t}, N=#{n}"
      end
    end
  end

  test "fermions never share a level" do
    for log_t <- [-1.3, 0.0, 1.3] do
      fd = QuantumStats.curves(:math.pow(10, log_t), 25).fd
      assert Enum.all?(fd, &(&1 <= 1.0))
    end
  end

  test "cold bosons pile onto the ground level and cold fermions fill from the bottom" do
    %{be: be, fd: fd} = QuantumStats.curves(:math.pow(10, -1.3), 18)

    assert hd(be) > 17.9
    assert fd |> Enum.take(18) |> Enum.all?(&(&1 > 0.99))
    assert fd |> Enum.drop(18) |> Enum.all?(&(&1 < 0.01))
  end

  test "hot enough, all three agree on the sparse upper levels" do
    %{mb: mb, be: be, fd: fd} = QuantumStats.curves(20.0, 3)

    for {m, b, f} <- Enum.zip([mb, be, fd]) do
      assert_in_delta b, m, 0.02
      assert_in_delta f, m, 0.02
    end
  end

  test "there is one value per level" do
    assert QuantumStats.curves(1.0, 18).mb |> length() == QuantumStats.levels()
  end
end
