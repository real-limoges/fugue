defmodule FugueWeb.LabLive.Bayes do
  @moduledoc """
  Three small Bayesian demos (search, rate, decision) that all end with
  a posterior. Rendering is fully server-side: no JS hooks, no push_event.
  """

  use FugueWeb, :live_view

  alias FugueWeb.LabLive.Charts

  @rows 5
  @cols 5
  @cells @rows * @cols
  @search_peak_row 1
  @search_peak_col 1
  @search_sigma 1.4

  @prior_alpha 2.0
  @prior_beta 0.4
  @true_rate 4.2
  @rate_x_max 12.0

  @threshold_min 0.5
  @threshold_max 10.0
  @threshold_step 0.1

  @density_grid_n 250
  @chart_width 700
  @chart_height 360
  @search_size 360

  # Section accent (also used by the shaded posterior tail).
  @posterior_color "#ff8a28"
  @prior_color "#888888"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:rows, @rows)
     |> assign(:cols, @cols)
     |> assign(:search_prior, build_search_prior())
     |> assign(:search_grid, build_search_prior())
     |> assign(:search_searched, MapSet.new())
     |> assign(:search_truth, random_cell())
     |> assign(:search_found, nil)
     |> assign(:observed_count, 0)
     |> assign(:observed_years, 0)
     |> assign(:observation_log, [])
     |> assign(:decision_threshold, 5.0)
     |> assign(:threshold_min, @threshold_min)
     |> assign(:threshold_max, @threshold_max)
     |> assign(:threshold_step, @threshold_step)}
  end

  def handle_event("search_cell", %{"index" => i}, socket) do
    i = String.to_integer(i)

    cond do
      socket.assigns.search_found != nil -> {:noreply, socket}
      MapSet.member?(socket.assigns.search_searched, i) -> {:noreply, socket}
      i == socket.assigns.search_truth -> {:noreply, mark_found(socket, i)}
      true -> {:noreply, mark_empty(socket, i)}
    end
  end

  def handle_event("reset_search", _, socket) do
    {:noreply,
     socket
     |> assign(:search_grid, socket.assigns.search_prior)
     |> assign(:search_searched, MapSet.new())
     |> assign(:search_truth, random_cell())
     |> assign(:search_found, nil)}
  end

  def handle_event("observe_year", _, socket) do
    count = poisson_sample(@true_rate)

    {:noreply,
     socket
     |> assign(:observed_count, socket.assigns.observed_count + count)
     |> assign(:observed_years, socket.assigns.observed_years + 1)
     |> assign(:observation_log, [count | socket.assigns.observation_log])}
  end

  def handle_event("reset_rate", _, socket) do
    {:noreply,
     socket
     |> assign(:observed_count, 0)
     |> assign(:observed_years, 0)
     |> assign(:observation_log, [])}
  end

  def handle_event("set_threshold", %{"value" => v}, socket) do
    case Float.parse(v) do
      {f, _} ->
        clamped = f |> max(@threshold_min) |> min(@threshold_max)
        {:noreply, assign(socket, :decision_threshold, clamped)}

      :error ->
        {:noreply, socket}
    end
  end

  defp mark_found(socket, i) do
    socket
    |> assign(:search_found, i)
    |> assign(:search_searched, MapSet.put(socket.assigns.search_searched, i))
  end

  defp mark_empty(socket, i) do
    socket
    |> assign(:search_grid, zero_and_renormalize(socket.assigns.search_grid, i))
    |> assign(:search_searched, MapSet.put(socket.assigns.search_searched, i))
  end

  defp posterior(assigns) do
    {@prior_alpha + assigns.observed_count, @prior_beta + assigns.observed_years}
  end

  defp build_search_prior do
    raw =
      for r <- 0..(@rows - 1), c <- 0..(@cols - 1) do
        d2 = (r - @search_peak_row) ** 2 + (c - @search_peak_col) ** 2
        :math.exp(-d2 / (2.0 * @search_sigma * @search_sigma))
      end

    total = Enum.sum(raw)
    Enum.map(raw, &(&1 / total))
  end

  defp zero_and_renormalize(grid, i) do
    zeroed = List.replace_at(grid, i, 0.0)
    total = Enum.sum(zeroed)
    if total <= 0, do: zeroed, else: Enum.map(zeroed, &(&1 / total))
  end

  defp random_cell, do: :rand.uniform(@cells) - 1

  # Knuth's algorithm. Adequate for our small means (≤ ~20).
  defp poisson_sample(mean) do
    l = :math.exp(-mean)
    poisson_step(l, 1.0, 0)
  end

  defp poisson_step(l, p, k) do
    p = p * :rand.uniform()
    if p <= l, do: k, else: poisson_step(l, p, k + 1)
  end

  def render(assigns) do
    {pa, pb} = posterior(assigns)

    assigns =
      assign(assigns,
        prior_alpha: @prior_alpha,
        prior_beta: @prior_beta,
        post_alpha: pa,
        post_beta: pb,
        post_mean: pa / pb
      )

    ~H"""
    <div class="p-6 max-w-4xl mx-auto">
      <header class="mb-10">
        <p class="font-mono text-[10px] uppercase tracking-[0.25em] text-primary/60 mb-3">
          / lab / bayes
        </p>
        <h1 class="text-2xl font-mono font-semibold text-base-content mb-3">
          Bayesian, the noun
        </h1>
        <p class="text-sm text-base-content/60 leading-relaxed max-w-2xl">
          Three small problems. Each one ends with a probability distribution
          over the thing you didn't know. Whatever you want to know after that
          is just an integral over it. The framework I work on at my day job
          dresses this up; the dressing is there so the same trick scales up
          to models that don't fit on a page.
        </p>
      </header>

      <.search_section
        rows={@rows}
        cols={@cols}
        grid={@search_grid}
        searched={@search_searched}
        found={@search_found}
      />

      <.rate_section
        prior_alpha={@prior_alpha}
        prior_beta={@prior_beta}
        post_alpha={@post_alpha}
        post_beta={@post_beta}
        post_mean={@post_mean}
        observed_years={@observed_years}
        observed_count={@observed_count}
      />

      <.decision_section
        post_alpha={@post_alpha}
        post_beta={@post_beta}
        threshold={@decision_threshold}
        threshold_min={@threshold_min}
        threshold_max={@threshold_max}
        threshold_step={@threshold_step}
      />
    </div>
    """
  end

  ## Section components

  attr :rows, :integer, required: true
  attr :cols, :integer, required: true
  attr :grid, :list, required: true
  attr :searched, MapSet, required: true
  attr :found, :integer, default: nil

  defp search_section(assigns) do
    cells = build_search_cells(assigns)
    assigns = assign(assigns, cells: cells, size: @search_size)

    ~H"""
    <section class="mb-14">
      <h2 class="text-lg font-semibold text-white mb-1">Where are the keys?</h2>
      <p class="text-gray-400 text-sm mb-4 max-w-2xl">
        Twenty-five rooms. The shading is where you think you left them --
        your prior. Click a room to look. If they're not in there, the
        room's mass collapses to zero and the rest of the grid soaks it up.
        Bayes' rule is that rearrangement: the total never changes, it just
        moves.
      </p>

      <div class="flex flex-col md:flex-row md:items-start gap-6">
        <svg
          viewBox={"0 0 #{@size} #{@size}"}
          width={@size}
          height={@size}
          class="rounded-lg bg-base-200"
          style="flex-shrink: 0;"
        >
          <g :for={cell <- @cells}>
            <rect
              x={cell.x}
              y={cell.y}
              width={cell.w}
              height={cell.h}
              rx="4"
              ry="4"
              fill={cell.fill}
              stroke={cell.stroke}
              stroke-width={cell.stroke_width}
              style={cell.cursor_style}
              phx-click={cell.click && "search_cell"}
              phx-value-index={cell.click && cell.index}
            />
            <text
              :if={cell.label}
              x={cell.cx}
              y={cell.cy}
              text-anchor="middle"
              fill={cell.label_color}
              font-size={cell.label_size}
              font-family="monospace"
              font-weight={cell.label_weight}
            >
              {cell.label}
            </text>
          </g>
        </svg>

        <div class="flex-1 space-y-3 text-xs text-gray-500 font-mono">
          <p>
            <span class="text-gray-300">Searches: {MapSet.size(@searched)}</span>
            <%= if @found != nil do %>
              ·
              <span class="text-primary">
                found in {MapSet.size(@searched)} {if MapSet.size(@searched) == 1,
                  do: "try",
                  else: "tries"}
              </span>
            <% end %>
          </p>
          <button
            phx-click="reset_search"
            class="btn btn-xs btn-ghost border border-white/25 text-gray-300 hover:text-white hover:border-white/40 font-mono"
          >
            Reset (new hidden cell)
          </button>
          <p class="leading-relaxed pt-2 max-w-md">
            This is the rule that found the USS Scorpion in 1968 and
            Air France 447 in 2011. A prior over the ocean floor, narrowed
            by every place the search team looked and didn't find anything.
            The same thing you just did to the grid, on a much bigger grid.
          </p>
        </div>
      </div>
    </section>
    """
  end

  attr :prior_alpha, :float, required: true
  attr :prior_beta, :float, required: true
  attr :post_alpha, :float, required: true
  attr :post_beta, :float, required: true
  attr :post_mean, :float, required: true
  attr :observed_years, :integer, required: true
  attr :observed_count, :integer, required: true

  defp rate_section(assigns) do
    chart = build_rate_chart(assigns)
    assigns = assign(assigns, chart: chart)

    ~H"""
    <section class="mb-14">
      <h2 class="text-lg font-semibold text-white mb-1">A rate, learned from years</h2>
      <p class="text-gray-400 text-sm mb-4 max-w-2xl">
        Earthquakes per year in the Bay Area, where I live; not a textbook
        example for me. Each year is a draw from <code class="text-primary/70">Poisson(rate)</code>; the rate itself
        is the thing you want, and you don't know it. The dim curve is
        what you'd guess about it before any data shows up. Click <em>observe a year</em>
        and watch the bright curve narrow as the
        years stack up.
      </p>

      <.density_chart chart={@chart} />

      <div class="mt-4 flex flex-wrap items-center gap-3">
        <button
          phx-click="observe_year"
          class="btn btn-sm btn-ghost border border-primary/60 text-primary font-mono"
        >
          Observe a year
        </button>
        <button
          phx-click="reset_rate"
          class="btn btn-xs btn-ghost border border-white/25 text-gray-300 hover:text-white hover:border-white/40 font-mono"
        >
          Reset
        </button>
        <p class="text-xs text-gray-500 font-mono ml-2">
          {@observed_years} {if @observed_years == 1, do: "year", else: "years"} · {@observed_count} total events ·
          posterior mean <span class="text-primary/80">{Float.round(@post_mean, 2)}</span>
        </p>
      </div>

      <p class="mt-5 text-xs text-gray-500 font-mono leading-relaxed max-w-2xl">
        Closed-form here: a
        <code class="text-gray-400">
          Gamma({Float.round(@prior_alpha, 1)}, {Float.round(@prior_beta, 1)})
        </code>
        prior times a Poisson likelihood is another Gamma, <code class="text-primary/70">Gamma({Float.round(@post_alpha, 1)}, {Float.round(@post_beta, 1)})</code>.
        Same shape, sharper. For models without a clean conjugate, the framework
        does the same thing numerically; the answer is the same kind of object
        either way.
      </p>
    </section>
    """
  end

  attr :post_alpha, :float, required: true
  attr :post_beta, :float, required: true
  attr :threshold, :float, required: true
  attr :threshold_min, :float, required: true
  attr :threshold_max, :float, required: true
  attr :threshold_step, :float, required: true

  defp decision_section(assigns) do
    chart = build_decision_chart(assigns)
    assigns = assign(assigns, chart: chart)

    ~H"""
    <section class="mb-6">
      <h2 class="text-lg font-semibold text-white mb-1">Asking the posterior a question</h2>
      <p class="text-gray-400 text-sm mb-4 max-w-2xl">
        You have a posterior; the section above made one. Reducing it to a
        single number ("the rate is 3.5") throws away most of what's there.
        Usually what you want to know is more like <em>is it above some threshold I care about?</em>
        The posterior already has that. Move the threshold; read the integral off the curve.
      </p>

      <.density_chart chart={@chart} />

      <form phx-change="set_threshold" class="mt-4 flex items-center gap-4">
        <label class="text-xs font-mono text-gray-400">Threshold</label>
        <input
          type="range"
          name="value"
          min={@threshold_min}
          max={@threshold_max}
          step={@threshold_step}
          value={@threshold}
          class="range range-xs range-primary flex-1 max-w-md"
        />
        <span class="text-xs font-mono text-primary/80 w-12 text-right">
          {Float.round(@threshold, 1)}
        </span>
      </form>

      <p class="mt-5 text-xs text-gray-500 font-mono leading-relaxed max-w-2xl">
        The shaded area is <code class="text-primary/70">P(rate &gt; threshold | data)</code>.
        Same posterior as the section above; observe more years there and
        watch the answer here move. Every other question you'd ask about the
        rate is just a different integral over the same object.
      </p>
    </section>
    """
  end

  ## Chart component (frame + layers)

  attr :chart, :map, required: true

  defp density_chart(assigns) do
    ~H"""
    <svg
      viewBox={"0 0 #{@chart.frame.width} #{@chart.frame.height}"}
      width="100%"
      height={@chart.frame.height}
      preserveAspectRatio="xMidYMid meet"
      class="rounded-lg bg-base-200"
    >
      <g opacity="0.15">
        <line
          :for={t <- @chart.frame.x_ticks}
          x1={t.x}
          y1={@chart.frame.margin.top}
          x2={t.x}
          y2={@chart.frame.margin.top + @chart.frame.inner_h}
          stroke="#fff"
          stroke-width="1"
        />
      </g>

      <line
        x1={@chart.frame.margin.left}
        y1={@chart.frame.margin.top + @chart.frame.inner_h}
        x2={@chart.frame.margin.left + @chart.frame.inner_w}
        y2={@chart.frame.margin.top + @chart.frame.inner_h}
        stroke="#555"
        stroke-width="1"
      />
      <line
        x1={@chart.frame.margin.left}
        y1={@chart.frame.margin.top}
        x2={@chart.frame.margin.left}
        y2={@chart.frame.margin.top + @chart.frame.inner_h}
        stroke="#555"
        stroke-width="1"
      />

      <text
        :for={t <- @chart.frame.x_ticks}
        x={t.x}
        y={@chart.frame.margin.top + @chart.frame.inner_h + 18}
        text-anchor="middle"
        fill="#888"
        font-size="11"
        font-family="monospace"
      >
        {Charts.format_tick(t.value)}
      </text>

      <text
        x={@chart.frame.margin.left + @chart.frame.inner_w / 2}
        y={@chart.frame.height - 4}
        text-anchor="middle"
        fill="#666"
        font-size="12"
        font-family="monospace"
      >
        {@chart.x_label}
      </text>
      <text
        x="12"
        y={@chart.frame.margin.top + @chart.frame.inner_h / 2}
        text-anchor="middle"
        fill="#666"
        font-size="12"
        font-family="monospace"
        transform={"rotate(-90, 12, #{@chart.frame.margin.top + @chart.frame.inner_h / 2})"}
      >
        {@chart.y_label}
      </text>

      <path
        :if={@chart.shaded}
        d={@chart.shaded.d}
        fill={@chart.shaded.fill}
        opacity={@chart.shaded.opacity}
      />

      <path
        :for={layer <- @chart.curves}
        d={layer.d}
        stroke={layer.color}
        stroke-width={layer.width}
        fill="none"
        opacity={layer.opacity}
        stroke-dasharray={layer.dasharray}
      />

      <%= if @chart.threshold_line do %>
        <line
          x1={@chart.threshold_line.x}
          y1={@chart.threshold_line.y1}
          x2={@chart.threshold_line.x}
          y2={@chart.threshold_line.y2}
          stroke="#fff"
          stroke-width="1.5"
          opacity="0.6"
          stroke-dasharray="5,3"
        />
      <% end %>

      <%= if @chart.mean_marker do %>
        <line
          x1={@chart.mean_marker.x}
          y1={@chart.mean_marker.y1}
          x2={@chart.mean_marker.x}
          y2={@chart.mean_marker.y2}
          stroke={@chart.mean_marker.color}
          stroke-width="1"
          opacity="0.4"
          stroke-dasharray="3,3"
        />
        <text
          x={@chart.mean_marker.x}
          y={@chart.mean_marker.label_y}
          text-anchor="middle"
          fill={@chart.mean_marker.color}
          font-size="11"
          font-family="monospace"
        >
          mean {Float.round(@chart.mean_marker.value, 2)}
        </text>
      <% end %>

      <text
        :if={@chart.readout}
        x={@chart.readout.x}
        y={@chart.readout.y}
        text-anchor="end"
        fill={@chart.readout.color}
        font-size="16"
        font-family="monospace"
        font-weight="bold"
      >
        {@chart.readout.text}
      </text>
    </svg>
    """
  end

  ## Per-section data builders

  defp build_search_cells(%{rows: rows, cols: cols, grid: grid, searched: searched, found: found}) do
    padding = 12
    gap = 4
    inner = @search_size - 2 * padding
    cell_w = (inner - gap * (cols - 1)) / cols
    cell_h = (inner - gap * (rows - 1)) / rows
    max_p = Enum.max(grid, fn -> 0.0 end)
    interactive? = found == nil

    for r <- 0..(rows - 1), c <- 0..(cols - 1) do
      i = r * cols + c
      p = Enum.at(grid, i)
      is_searched = MapSet.member?(searched, i)
      is_truth = found == i

      x = padding + c * (cell_w + gap)
      y = padding + r * (cell_h + gap)

      %{
        index: i,
        x: x,
        y: y,
        cx: x + cell_w / 2,
        cy: y + cell_h / 2 + 4,
        w: cell_w,
        h: cell_h,
        fill: if(is_searched, do: "#1e1e24", else: prob_color(p, max_p)),
        stroke:
          cond do
            is_truth -> @posterior_color
            is_searched -> "#444"
            true -> "#000"
          end,
        stroke_width: if(is_truth, do: "2", else: "1"),
        cursor_style: if(interactive?, do: "cursor: pointer;", else: "cursor: default;"),
        click: interactive? and not is_searched,
        label: cell_label(p, max_p, is_searched, is_truth),
        label_color: cell_label_color(p, max_p, is_searched, is_truth),
        label_size: if(is_truth, do: "13", else: "11"),
        label_weight: if(is_truth, do: "bold", else: "normal")
      }
    end
  end

  defp cell_label(_, _, _, true), do: "found"
  defp cell_label(_, _, true, _), do: "--"
  defp cell_label(p, _max_p, false, _) when p >= 0.005, do: "#{round(p * 100)}%"
  defp cell_label(_, _, _, _), do: nil

  defp cell_label_color(_, _, _, true), do: @posterior_color
  defp cell_label_color(_, _, true, _), do: "#666"
  defp cell_label_color(p, max_p, _, _) when max_p > 0 and p / max_p > 0.6, do: "#1e1e24"
  defp cell_label_color(_, _, _, _), do: "#aaa"

  defp prob_color(p, _) when p <= 0, do: "#1e1e24"

  defp prob_color(p, max_p) do
    t = min(1.0, p / max(max_p, 1.0e-9))
    r = round(30 + (255 - 30) * t)
    g = round(30 + (138 - 30) * t)
    b = round(36 + (40 - 36) * t)
    "rgb(#{r}, #{g}, #{b})"
  end

  defp build_rate_chart(%{
         prior_alpha: pa0,
         prior_beta: pb0,
         post_alpha: pa,
         post_beta: pb
       }) do
    xs = Charts.linspace(0.001, @rate_x_max, @density_grid_n)
    prior_pdf = Charts.gamma_density(xs, pa0, pb0)
    post_pdf = Charts.gamma_density(xs, pa, pb)
    y_max = (prior_pdf ++ post_pdf) |> Enum.max() |> Kernel.*(1.08)

    frame = build_frame(y_max)

    curves = [
      density_layer(xs, prior_pdf, frame, @prior_color, "1.5", "0.5", "5,3"),
      density_layer(xs, post_pdf, frame, @posterior_color, "2", "1", nil)
    ]

    post_mean = pa / pb

    %{
      frame: frame,
      x_label: "Rate (events / year)",
      y_label: "Density",
      curves: curves,
      shaded: nil,
      threshold_line: nil,
      mean_marker: build_mean_marker(post_mean, frame, y_max),
      readout: nil
    }
  end

  defp build_decision_chart(%{
         post_alpha: pa,
         post_beta: pb,
         threshold: threshold
       }) do
    xs = Charts.linspace(0.001, @rate_x_max, @density_grid_n)
    pdf = Charts.gamma_density(xs, pa, pb)
    y_max = pdf |> Enum.max() |> Kernel.*(1.08)

    frame = build_frame(y_max)

    curves = [density_layer(xs, pdf, frame, @posterior_color, "2", "1", nil)]

    shaded =
      case Charts.tail_polygon_path(xs, pdf, threshold, frame.scale_x, frame.scale_y) do
        nil -> nil
        d -> %{d: d, fill: @posterior_color, opacity: "0.32"}
      end

    tail_p = Charts.tail_probability(xs, pdf, threshold)

    %{
      frame: frame,
      x_label: "Rate (events / year)",
      y_label: "Density",
      curves: curves,
      shaded: shaded,
      threshold_line: %{
        x: frame.scale_x.(threshold),
        y1: frame.scale_y.(0),
        y2: frame.scale_y.(y_max)
      },
      mean_marker: nil,
      readout: %{
        x: frame.margin.left + frame.inner_w - 8,
        y: frame.margin.top + 18,
        color: @posterior_color,
        text: "P(rate > #{Float.round(threshold, 1)}) = #{Float.round(tail_p * 100, 1)}%"
      }
    }
  end

  defp build_frame(y_max) do
    Charts.axis_frame(
      width: @chart_width,
      height: @chart_height,
      x_range: {0, @rate_x_max},
      y_range: {0, y_max},
      x_ticks: Charts.linspace(0, @rate_x_max, 7) |> Enum.map(&Float.round(&1, 1)),
      y_ticks: []
    )
  end

  defp density_layer(xs, ys, frame, color, width, opacity, dasharray) do
    %{
      d: Charts.polyline_path(xs, ys, frame.scale_x, frame.scale_y),
      color: color,
      width: width,
      opacity: opacity,
      dasharray: dasharray
    }
  end

  defp build_mean_marker(mean, _frame, _y_max) when mean <= 0, do: nil

  defp build_mean_marker(mean, frame, y_max) when mean < @rate_x_max do
    %{
      x: frame.scale_x.(mean),
      y1: frame.scale_y.(0),
      y2: frame.scale_y.(y_max * 0.92),
      label_y: frame.scale_y.(y_max * 0.94) - 4,
      color: @posterior_color,
      value: mean
    }
  end

  defp build_mean_marker(_, _, _), do: nil
end
