defmodule FugueWeb.MenagerieLive.QuantumStats do
  @moduledoc """
  Occupation histograms for Maxwell-Boltzmann, Bose-Einstein, and Fermi-Dirac
  statistics overlaid on one panel. A temperature slider drives all three
  toward the classical limit at high T and blows them apart at low T.

  The math is `Fugue.Menagerie.QuantumStats`; the chart is server-rendered
  SVG. It was a canvas hook until 2026-11-25.
  """

  use FugueWeb, :live_view

  import FugueWeb.IndexComponents, only: [menagerie_header: 1]

  alias Fugue.Menagerie.QuantumStats
  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider
  import FugueWeb.MoodLive.SvgMath, only: [fmt: 1]

  @defaults %{"log_temperature" => 0.0, "particles" => 18}

  @sliders [
    Slider.new(
      key: "log_temperature",
      label: "Temperature",
      min: -1.3,
      max: 1.3,
      step: 0.01,
      format: &__MODULE__.format_log_temperature/1
    ),
    Slider.new(
      key: "particles",
      label: "Particles",
      min: 3,
      max: 25,
      step: 1,
      cast: &trunc/1,
      format: &Integer.to_string/1
    )
  ]

  # Chart geometry, in viewBox units. The SVG scales with its container, so
  # the viewBox is narrow enough that 10-unit labels render at 10px or more
  # on a desktop column.
  @chart_w 720
  @chart_h 320
  @pad_l 52
  @pad_r 20
  @pad_t 24
  @pad_b 44
  @y_min 0.01

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  # The figure is server-rendered SVG, so a slider change is just an
  # assign; there is no hook to push to.
  @impl true
  def handle_event("update_params", form, socket) do
    {:noreply,
     assign(socket, :params, AnimatedCard.parse_params(form, socket.assigns.params, @sliders))}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, :params, @defaults)}
  end

  @doc false
  @spec format_log_temperature(number()) :: String.t()
  def format_log_temperature(log_t) do
    "kT = " <> :erlang.float_to_binary(:math.pow(10, log_t), decimals: 2)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="quantum-stats-menagerie p-4 max-w-6xl mx-auto">
      <.menagerie_header title="Three ways to count">
        <p class="text-sm text-base-content/60 mt-1 max-w-3xl leading-relaxed">
          Drag the temperature to the hot end and the three curves sit right on
          top of each other, close enough that you'd think there was only one.
          Drag it cold and they come apart into shapes that look like they belong
          to different problems: a huge spike on the lowest level with nothing
          anywhere else, a flat shelf that drops off a cliff, and a smooth slide
          down from the left.
        </p>
        <p class="text-sm text-base-content/60 mt-3 max-w-3xl leading-relaxed">
          The only thing that differs is a rule about sharing. Bosons
          (Bose-Einstein, the spike) are happy to pile into the same state, as
          many as you like. Fermions (Fermi-Dirac, the cliff) can't share at
          all, so they fill the levels one at a time from the bottom, like seats
          in a theater. Classical particles (Maxwell-Boltzmann, the smooth slide)
          don't care either way. When it's hot there's so much room that nobody
          is competing for a state and the rule stops mattering; the cold end is
          where it shows.
        </p>
      </.menagerie_header>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <.chart
          t={:math.pow(10, @params["log_temperature"])}
          n={@params["particles"]}
        />
      </div>

      <.figure_source
        note="Bose-Einstein, Fermi-Dirac and Maxwell-Boltzmann occupancy over the same ladder of states. The only difference in the code is whether particles are allowed to share a level."
        repo={{"fugue", "lib/fugue/menagerie/quantum_stats.ex"}}
      />

      <div class="flex flex-wrap gap-2 mb-4">
        <button type="button" phx-click="reset" class="btn btn-xs btn-ghost">
          Reset
        </button>
      </div>

      <AnimatedCard.slider_grid
        sliders={@sliders}
        params={@params}
        class="grid grid-cols-1 sm:grid-cols-2 gap-4"
      />

      <.source_link repos={[{"fugue", "lib/fugue_web/live/menagerie_live/quantum_stats.ex"}]} />
    </div>
    """
  end

  # --- Chart ---
  #
  # Log y-axis: Maxwell-Boltzmann's exponential decay becomes a straight
  # line, the Bose-Einstein spike compresses, and the Fermi-Dirac shelf and
  # cliff stay legible. The top is N rounded up to a power of ten, keyed off
  # N rather than the data so the axis holds still while T is dragged.

  attr :t, :float, required: true
  attr :n, :integer, required: true

  defp chart(assigns) do
    plot_w = @chart_w - @pad_l - @pad_r
    plot_h = @chart_h - @pad_t - @pad_b
    y_max = :math.pow(10, Float.ceil(:math.log10(max(assigns.n, 2) * 1.05)))
    log_min = :math.log10(@y_min)
    log_span = :math.log10(y_max) - log_min
    last = QuantumStats.levels() - 1

    x = fn i -> @pad_l + i / last * plot_w end

    y = fn occ ->
      clamped = occ |> max(@y_min) |> min(y_max)
      @pad_t + plot_h - (:math.log10(clamped) - log_min) / log_span * plot_h
    end

    points = fn occ ->
      occ |> Enum.with_index() |> Enum.map(fn {o, i} -> {x.(i), y.(o)} end)
    end

    curves = QuantumStats.curves(assigns.t, assigns.n)
    fd = points.(curves.fd)

    decades =
      Enum.map(round(log_min)..round(:math.log10(y_max))//1, fn p ->
        %{y: y.(:math.pow(10, p)), label: decade_label(p)}
      end)

    assigns =
      assign(assigns,
        w: @chart_w,
        h: @chart_h,
        pad_l: @pad_l,
        pad_t: @pad_t,
        right: @pad_l + plot_w,
        bottom: @pad_t + plot_h,
        center_x: @pad_l + plot_w / 2,
        last: last,
        decades: decades,
        mb: polyline(points.(curves.mb)),
        be: polyline(points.(curves.be)),
        fd: polyline(fd),
        fd_dots: fd,
        lx: @pad_l + plot_w - 170,
        ly: @pad_t + 8
      )

    ~H"""
    <svg
      id="menagerie-quantum-stats-chart"
      viewBox={"0 0 #{@w} #{@h}"}
      class="block w-full h-auto text-base-content"
      role="img"
      aria-label="Occupation of each energy level under Bose-Einstein, Fermi-Dirac and Maxwell-Boltzmann statistics"
    >
      <line
        :for={d <- @decades}
        x1={@pad_l}
        y1={fmt(d.y)}
        x2={@right}
        y2={fmt(d.y)}
        stroke="currentColor"
        stroke-opacity="0.1"
      />
      <polyline
        points={"#{@pad_l},#{@pad_t} #{@pad_l},#{@bottom} #{@right},#{@bottom}"}
        fill="none"
        stroke="currentColor"
        stroke-opacity="0.3"
      />

      <g fill="currentColor" fill-opacity="0.7" font-size="10" font-family="ui-monospace, monospace">
        <text :for={d <- @decades} x={@pad_l - 6} y={fmt(d.y + 3)} text-anchor="end">
          {d.label}
        </text>
        <text x={fmt(@center_x)} y={@bottom + 28} text-anchor="middle">energy level →</text>
        <text x={@pad_l} y={@bottom + 16}>0</text>
        <text x={@right} y={@bottom + 16} text-anchor="end">{@last}</text>
        <text x={@pad_l - 44} y={@pad_t - 8}>occupation (log) ↑</text>
      </g>

      <polyline
        points={@mb}
        fill="none"
        stroke="currentColor"
        stroke-opacity="0.65"
        stroke-width="1.25"
        stroke-dasharray="4 4"
      />
      <polyline points={@fd} fill="none" stroke="var(--color-secondary)" stroke-width="1.25" />
      <circle
        :for={{cx, cy} <- @fd_dots}
        cx={fmt(cx)}
        cy={fmt(cy)}
        r="1.75"
        fill="var(--color-secondary)"
      />
      <polyline
        points={@be}
        fill="none"
        stroke="var(--color-secondary)"
        stroke-width="2.5"
        stroke-linejoin="round"
      />

      <g font-size="11" font-family="ui-sans-serif, system-ui, sans-serif">
        <line
          x1={fmt(@lx)}
          y1={@ly + 6}
          x2={fmt(@lx + 24)}
          y2={@ly + 6}
          stroke="var(--color-secondary)"
          stroke-width="2.5"
        />
        <line
          x1={fmt(@lx)}
          y1={@ly + 22}
          x2={fmt(@lx + 24)}
          y2={@ly + 22}
          stroke="var(--color-secondary)"
          stroke-width="1.25"
        />
        <circle
          :for={k <- 0..2}
          cx={fmt(@lx + 4 + k * 8)}
          cy={@ly + 22}
          r="1.75"
          fill="var(--color-secondary)"
        />
        <line
          x1={fmt(@lx)}
          y1={@ly + 38}
          x2={fmt(@lx + 24)}
          y2={@ly + 38}
          stroke="currentColor"
          stroke-opacity="0.65"
          stroke-width="1.25"
          stroke-dasharray="4 4"
        />
        <g fill="currentColor" fill-opacity="0.7">
          <text x={fmt(@lx + 32)} y={@ly + 10}>Bose-Einstein</text>
          <text x={fmt(@lx + 32)} y={@ly + 26}>Fermi-Dirac</text>
          <text x={fmt(@lx + 32)} y={@ly + 42}>Maxwell-Boltzmann</text>
        </g>
      </g>
    </svg>
    """
  end

  defp polyline(points), do: Enum.map_join(points, " ", fn {x, y} -> "#{fmt(x)},#{fmt(y)}" end)

  defp decade_label(p) when p >= 0, do: Integer.to_string(Integer.pow(10, p))
  defp decade_label(p), do: Float.to_string(:math.pow(10, p))
end
