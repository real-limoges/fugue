defmodule FugueWeb.LabLive.Bayes do
  use FugueWeb, :live_view

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

  def mount(_params, _session, socket) do
    prior = build_search_prior()
    truth = :rand.uniform(@cells) - 1

    {:ok,
     socket
     |> assign(:rows, @rows)
     |> assign(:cols, @cols)
     |> assign(:search_prior, prior)
     |> assign(:search_grid, prior)
     |> assign(:search_searched, MapSet.new())
     |> assign(:search_truth, truth)
     |> assign(:search_found, nil)
     |> assign(:observed_count, 0)
     |> assign(:observed_years, 0)
     |> assign(:observation_log, [])
     |> assign(:decision_threshold, 5.0)
     |> assign(:threshold_min, @threshold_min)
     |> assign(:threshold_max, @threshold_max)
     |> assign(:threshold_step, @threshold_step)}
  end

  def handle_event("bayes_search:ready", _, socket), do: {:noreply, push_search_state(socket)}

  def handle_event("bayes_rate:ready", _, socket), do: {:noreply, push_rate_state(socket)}

  def handle_event("bayes_decision:ready", _, socket), do: {:noreply, push_decision_state(socket)}

  def handle_event("search_cell", %{"index" => i}, socket) do
    i = to_int(i)

    cond do
      socket.assigns.search_found != nil ->
        {:noreply, socket}

      MapSet.member?(socket.assigns.search_searched, i) ->
        {:noreply, socket}

      i == socket.assigns.search_truth ->
        socket =
          socket
          |> assign(:search_found, i)
          |> assign(:search_searched, MapSet.put(socket.assigns.search_searched, i))

        {:noreply, push_search_state(socket)}

      true ->
        new_grid = zero_and_renormalize(socket.assigns.search_grid, i)
        new_searched = MapSet.put(socket.assigns.search_searched, i)

        socket =
          socket
          |> assign(:search_grid, new_grid)
          |> assign(:search_searched, new_searched)

        {:noreply, push_search_state(socket)}
    end
  end

  def handle_event("reset_search", _, socket) do
    truth = :rand.uniform(@cells) - 1

    socket =
      socket
      |> assign(:search_grid, socket.assigns.search_prior)
      |> assign(:search_searched, MapSet.new())
      |> assign(:search_truth, truth)
      |> assign(:search_found, nil)

    {:noreply, push_search_state(socket)}
  end

  def handle_event("observe_year", _, socket) do
    count = poisson_sample(@true_rate)

    socket =
      socket
      |> assign(:observed_count, socket.assigns.observed_count + count)
      |> assign(:observed_years, socket.assigns.observed_years + 1)
      |> assign(:observation_log, [count | socket.assigns.observation_log])

    {:noreply, socket |> push_rate_state() |> push_decision_state()}
  end

  def handle_event("reset_rate", _, socket) do
    socket =
      socket
      |> assign(:observed_count, 0)
      |> assign(:observed_years, 0)
      |> assign(:observation_log, [])

    {:noreply, socket |> push_rate_state() |> push_decision_state()}
  end

  def handle_event("set_threshold", %{"value" => v}, socket) do
    case Float.parse(v) do
      {f, _} ->
        clamped = f |> max(@threshold_min) |> min(@threshold_max)
        socket = assign(socket, :decision_threshold, clamped)
        {:noreply, push_decision_state(socket)}

      :error ->
        {:noreply, socket}
    end
  end

  defp push_search_state(socket) do
    push_event(socket, "bayes_search:state", %{
      grid: socket.assigns.search_grid,
      searched: MapSet.to_list(socket.assigns.search_searched),
      found: socket.assigns.search_found
    })
  end

  defp push_rate_state(socket) do
    {pa, pb} = posterior(socket.assigns)

    push_event(socket, "bayes_rate:state", %{
      prior_alpha: @prior_alpha,
      prior_beta: @prior_beta,
      post_alpha: pa,
      post_beta: pb,
      x_max: @rate_x_max
    })
  end

  defp push_decision_state(socket) do
    {pa, pb} = posterior(socket.assigns)

    push_event(socket, "bayes_decision:state", %{
      post_alpha: pa,
      post_beta: pb,
      threshold: socket.assigns.decision_threshold,
      x_max: @rate_x_max
    })
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

  # Knuth's algorithm. Adequate for our small means (≤ ~20).
  defp poisson_sample(mean) do
    l = :math.exp(-mean)
    poisson_step(l, 1.0, 0)
  end

  defp poisson_step(l, p, k) do
    p = p * :rand.uniform()
    if p <= l, do: k, else: poisson_step(l, p, k + 1)
  end

  defp to_int(i) when is_integer(i), do: i
  defp to_int(i) when is_binary(i), do: String.to_integer(i)

  def render(assigns) do
    {pa, pb} = posterior(assigns)
    post_mean = pa / pb

    assigns =
      assign(assigns,
        prior_alpha: @prior_alpha,
        prior_beta: @prior_beta,
        post_alpha: pa,
        post_beta: pb,
        post_mean: post_mean
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
          dresses this up; the dressing is mostly so the same trick scales up
          to models that don't fit on a page.
        </p>
      </header>

      <%!-- Section 1: Bayesian search --%>
      <section class="mb-14">
        <h2 class="text-lg font-semibold text-white mb-1">Where are the keys?</h2>
        <p class="text-gray-400 text-sm mb-4 max-w-2xl">
          Twenty-five rooms. The shading is where you think you left them —
          your prior. Click a room to look. If they're not in there, the
          room's mass collapses to zero and the rest of the grid soaks it up.
          Same total probability, rearranged. Bayes' rule is the rearrangement.
        </p>

        <div class="flex flex-col md:flex-row md:items-start gap-6">
          <div
            id="bayes-search-viz"
            phx-hook="BayesSearch"
            phx-update="ignore"
            class="rounded-lg bg-base-200"
            style="width: 360px; height: 360px; flex-shrink: 0;"
          />

          <div class="flex-1 space-y-3 text-xs text-gray-500 font-mono">
            <p>
              <span class="text-gray-300">Searches: {MapSet.size(@search_searched)}</span>
              <%= if @search_found != nil do %>
                ·
                <span class="text-primary">
                  found in {MapSet.size(@search_searched)} {if MapSet.size(@search_searched) == 1,
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
              Same trick, fewer rooms.
            </p>
          </div>
        </div>
      </section>

      <%!-- Section 2: Rate estimation --%>
      <section class="mb-14">
        <h2 class="text-lg font-semibold text-white mb-1">A rate, learned from years</h2>
        <p class="text-gray-400 text-sm mb-4 max-w-2xl">
          Earthquakes per year in the Bay Area, where I live; not a textbook
          example for me. Each year is a draw from <code class="text-primary/70">Poisson(rate)</code>; the rate itself
          is what you actually want, and you don't know it. The dim curve is
          what you'd guess about it before any data shows up. Click <em>observe a year</em>
          and watch the bright curve narrow as the
          years stack up.
        </p>

        <div
          id="bayes-rate-viz"
          phx-hook="BayesRate"
          phx-update="ignore"
          class="w-full rounded-lg bg-base-200"
          style="min-height: 360px;"
        />

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
          prior times a Poisson likelihood is another Gamma — <code class="text-primary/70">Gamma({Float.round(@post_alpha, 1)}, {Float.round(@post_beta, 1)})</code>.
          Same shape, sharper. For models without a clean conjugate, the framework
          does the same thing numerically; the answer is the same kind of object
          either way.
        </p>
      </section>

      <%!-- Section 3: Decision --%>
      <section class="mb-6">
        <h2 class="text-lg font-semibold text-white mb-1">Asking the posterior a question</h2>
        <p class="text-gray-400 text-sm mb-4 max-w-2xl">
          You have a posterior; the section above made one. Reducing it to a
          single number ("the rate is 3.5") throws away most of what's there.
          The real questions usually look more like: <em>is it above some threshold I care about?</em>
          The posterior
          already knows. Move the threshold; read the integral off the curve.
        </p>

        <div
          id="bayes-decision-viz"
          phx-hook="BayesDecision"
          phx-update="ignore"
          class="w-full rounded-lg bg-base-200"
          style="min-height: 360px;"
        />

        <form phx-change="set_threshold" class="mt-4 flex items-center gap-4">
          <label class="text-xs font-mono text-gray-400">Threshold</label>
          <input
            type="range"
            name="value"
            min={@threshold_min}
            max={@threshold_max}
            step={@threshold_step}
            value={@decision_threshold}
            class="range range-xs range-primary flex-1 max-w-md"
          />
          <span class="text-xs font-mono text-primary/80 w-12 text-right">
            {Float.round(@decision_threshold, 1)}
          </span>
        </form>

        <p class="mt-5 text-xs text-gray-500 font-mono leading-relaxed max-w-2xl">
          The shaded area is <code class="text-primary/70">P(rate &gt; threshold | data)</code>.
          Same posterior as the section above; observe more years there and
          watch the answer here move. Every other question you'd ask about the
          rate is just a different integral over the same object.
        </p>
      </section>
    </div>
    """
  end
end
