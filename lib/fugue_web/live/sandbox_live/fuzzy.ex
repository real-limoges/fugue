defmodule FugueWeb.SandboxLive.Fuzzy do
  @moduledoc """
  Fuzzy-logic experiments: triangular membership bands over Melbourne daily
  temperatures, and a small Mamdani fan controller that routes through Hazy
  via the Ish `/inference/mamdani` endpoint.
  """

  use FugueWeb, :live_view

  require Logger

  alias Fugue.Ish
  alias Fugue.Sandbox.{Fuzzy, Mamdani, MelbourneWeather}

  @default_center_offset 0.0
  @default_spread 1.0

  def mount(_params, _session, socket) do
    mfs = Fuzzy.build_mfs(@default_center_offset, @default_spread)

    {first_date, last_date} =
      case MelbourneWeather.date_range() do
        nil -> {"", ""}
        {f, l} -> {f, l}
      end

    socket =
      assign(socket,
        center_offset: @default_center_offset,
        spread: @default_spread,
        mfs: mfs,
        row_count: MelbourneWeather.count(),
        first_date: first_date,
        last_date: last_date,
        mamdani_temperature: Mamdani.default_temperature(),
        mamdani_humidity: Mamdani.default_humidity(),
        mamdani_response: nil,
        mamdani_crisp: nil,
        mamdani_error: nil
      )

    {:ok, socket}
  end

  def handle_event("sandbox:bands_ready", _params, socket) do
    {:noreply, push_bands(socket)}
  end

  def handle_event("sandbox:mamdani_ready", _params, socket) do
    {:noreply, refresh_mamdani(socket)}
  end

  def handle_event(
        "update_mamdani_inputs",
        %{"temperature" => t_str, "humidity" => h_str},
        socket
      ) do
    temperature = parse_float(t_str, socket.assigns.mamdani_temperature)
    humidity = parse_float(h_str, socket.assigns.mamdani_humidity)

    if temperature == socket.assigns.mamdani_temperature and
         humidity == socket.assigns.mamdani_humidity do
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(mamdani_temperature: temperature, mamdani_humidity: humidity)
        |> refresh_mamdani()

      {:noreply, socket}
    end
  end

  def handle_event(
        "update_fuzzy_params",
        %{"center_offset" => co_str, "spread" => s_str},
        socket
      ) do
    center_offset = parse_float(co_str, socket.assigns.center_offset)
    spread = parse_float(s_str, socket.assigns.spread)

    if center_offset == socket.assigns.center_offset and spread == socket.assigns.spread do
      {:noreply, socket}
    else
      mfs = Fuzzy.build_mfs(center_offset, spread)

      socket =
        socket
        |> assign(center_offset: center_offset, spread: spread, mfs: mfs)
        |> push_bands()

      {:noreply, socket}
    end
  end

  defp push_bands(socket) do
    %{mfs: mfs} = socket.assigns
    bands = Fuzzy.bands(MelbourneWeather.rows(), mfs)

    push_event(socket, "update-bands", %{
      series: bands,
      mfs:
        Enum.map(mfs, fn mf ->
          %{name: mf.name, color: mf.color, a: mf.a, b: mf.b, c: mf.c}
        end),
      bounds: [0.0, 48.0]
    })
  end

  defp refresh_mamdani(socket) do
    %{mamdani_temperature: t, mamdani_humidity: h} = socket.assigns
    request = Mamdani.request(t, h)

    case Ish.mamdani(request) do
      {:ok, response} ->
        summaries = Mamdani.rule_summaries()

        strengths =
          response
          |> Map.get("rule_strengths", [])
          |> pad_strengths(length(summaries))

        rules =
          summaries
          |> Enum.zip(strengths)
          |> Enum.map(fn {%{text: text, output_term: term}, strength} ->
            %{text: text, output_term: term, strength: strength}
          end)

        crisp = Map.get(response, "crisp", %{})

        socket
        |> assign(
          mamdani_response: response,
          mamdani_crisp: Map.get(crisp, "fan_speed"),
          mamdani_error: nil
        )
        |> push_event("update-mamdani", %{
          mfs: Mamdani.mfs(),
          rules: rules,
          inputs: %{temperature: t, humidity: h},
          input_degrees: Map.get(response, "input_degrees", %{}),
          output_curves: Map.get(response, "output_curves", %{}),
          crisp: crisp
        })

      {:error, reason} ->
        Logger.error("Ish mamdani call failed: #{inspect(reason)}")
        assign(socket, mamdani_error: "inference service unavailable")
    end
  end

  defp pad_strengths(strengths, expected) when is_list(strengths) do
    actual = length(strengths)

    cond do
      actual == expected ->
        strengths

      actual < expected ->
        Logger.warning(
          "Ish returned #{actual} rule strengths, expected #{expected}; padding with zeros"
        )

        strengths ++ List.duplicate(0.0, expected - actual)

      true ->
        Logger.warning("Ish returned #{actual} rule strengths, expected #{expected}; truncating")

        Enum.take(strengths, expected)
    end
  end

  defp pad_strengths(_other, expected) do
    Logger.warning("Ish returned non-list rule_strengths; using zeros")
    List.duplicate(0.0, expected)
  end

  defp parse_float(str, default) do
    case Float.parse(str) do
      {v, _} -> v
      :error -> default
    end
  end

  defp format_number(n, decimals) when is_number(n) do
    :erlang.float_to_binary(n / 1, decimals: decimals)
  end

  def render(assigns) do
    ~H"""
    <div class="sandbox-page p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/sandbox"} class="text-gray-500 hover:text-gray-300">
          ← Sandbox
        </.link>
      </nav>

      <header class="mb-12">
        <h1 class="text-3xl font-semibold text-gray-100 mb-3">Fuzzy logic</h1>
        <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
          Two experiments in fuzzy sets. The first reshapes triangular membership
          functions over four years of Melbourne daily temperatures. The second
          runs a Mamdani inference controller server-side through Hazy and lets
          you watch the rules fire in real time.
        </p>
      </header>

      <section class="mb-16 pb-12 border-b border-white/5">
        <header class="mb-6">
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Experiment</p>
          <h2 class="text-2xl font-semibold text-gray-100 mb-3">Fuzzy temperature bands</h2>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl mb-3">
            Hard categories lose the gradient. A 22°C day isn't exactly <em>mild</em>
            and exactly nothing else — it's mostly mild, a little cool, a little warm.
            Five overlapping triangular membership functions let every day hold partial
            membership in every fuzzy set at once.
          </p>
          <p class="text-xs text-gray-500 max-w-3xl">
            Data: {@row_count} days of daily max temperatures from Melbourne Airport
            (GHCN-D {@first_date} → {@last_date}).
          </p>
        </header>

        <form phx-change="update_fuzzy_params" class="mb-8">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-3xl">
            <label class="block">
              <div class="flex justify-between items-baseline mb-2">
                <span class="text-xs uppercase tracking-wider text-gray-400">Center offset</span>
                <span class="text-xs text-gray-500 font-mono tabular-nums">
                  {format_number(@center_offset, 1)} °C
                </span>
              </div>
              <input
                type="range"
                name="center_offset"
                min="-10"
                max="10"
                step="0.5"
                value={@center_offset}
                phx-debounce="50"
                class="range range-xs range-primary"
              />
              <p class="text-xs text-gray-500 mt-1">
                Shift all five peaks left or right along the temperature axis.
              </p>
            </label>

            <label class="block">
              <div class="flex justify-between items-baseline mb-2">
                <span class="text-xs uppercase tracking-wider text-gray-400">Spread</span>
                <span class="text-xs text-gray-500 font-mono tabular-nums">
                  {format_number(@spread, 2)}×
                </span>
              </div>
              <input
                type="range"
                name="spread"
                min="0.3"
                max="2.0"
                step="0.05"
                value={@spread}
                phx-debounce="50"
                class="range range-xs range-primary"
              />
              <p class="text-xs text-gray-500 mt-1">
                Widen the triangles for more blending between adjacent sets.
              </p>
            </label>
          </div>
        </form>

        <div class="mb-3 flex flex-wrap gap-2">
          <%= for mf <- @mfs do %>
            <span
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border"
              style={"border-color: #{mf.color}; color: #{mf.color}"}
            >
              <span class="w-2 h-2 rounded-full" style={"background: #{mf.color}"}></span>
              {mf.name}
              <span class="opacity-60">· peak {format_number(mf.b, 1)}°C</span>
            </span>
          <% end %>
        </div>

        <div class="rounded-lg bg-base-200 p-4">
          <div
            id="sandbox-temperature-bands"
            phx-hook="TemperatureBands"
            phx-update="ignore"
            style="min-height: 440px;"
          >
          </div>
          <p class="mt-3 max-w-3xl text-xs leading-snug text-gray-500">
            Top strip: the five triangular membership functions on the temperature
            axis — drag the sliders to reshape them. Bottom: for every day in the
            dataset, the bands show how much that day belongs to each set.
            Memberships are normalized so every column fills the full height;
            hover for the exact breakdown.
          </p>
        </div>
      </section>

      <section class="mb-16 pb-12">
        <header class="mb-6">
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Experiment</p>
          <h2 class="text-2xl font-semibold text-gray-100 mb-3">Mamdani fan controller</h2>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl mb-3">
            A fuzzy controller the shape of an old-school rule of thumb: if it's hot
            and humid, run the fan hard; if it's cold, leave it off. Two crisp inputs
            get fuzzified, seven rules fire with varying strength, the output terms
            get clipped and aggregated, and the centroid of that aggregated shape is
            the crisp fan speed.
          </p>
          <p class="text-xs text-gray-500 max-w-3xl">
            Math runs server-side through Hazy (Haskell) via the Ish
            <code class="text-gray-400">/inference/mamdani</code>
            endpoint. Drag the sliders to watch the rule firings, output shape, and
            defuzzified crisp value respond.
          </p>
        </header>

        <form phx-change="update_mamdani_inputs" class="mb-8">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-3xl">
            <label class="block">
              <div class="flex justify-between items-baseline mb-2">
                <span class="text-xs uppercase tracking-wider text-gray-400">Temperature</span>
                <span class="text-xs text-gray-500 font-mono tabular-nums">
                  {format_number(@mamdani_temperature, 1)} °C
                </span>
              </div>
              <input
                type="range"
                name="temperature"
                min="0"
                max="40"
                step="0.5"
                value={@mamdani_temperature}
                phx-debounce="50"
                class="range range-xs range-primary"
              />
              <p class="text-xs text-gray-500 mt-1">
                Crisp temperature input, fuzzified into cold / warm / hot.
              </p>
            </label>

            <label class="block">
              <div class="flex justify-between items-baseline mb-2">
                <span class="text-xs uppercase tracking-wider text-gray-400">Humidity</span>
                <span class="text-xs text-gray-500 font-mono tabular-nums">
                  {format_number(@mamdani_humidity, 0)}%
                </span>
              </div>
              <input
                type="range"
                name="humidity"
                min="0"
                max="100"
                step="1"
                value={@mamdani_humidity}
                phx-debounce="50"
                class="range range-xs range-primary"
              />
              <p class="text-xs text-gray-500 mt-1">
                Relative humidity, fuzzified into dry / comfortable / humid.
              </p>
            </label>
          </div>
        </form>

        <%= if @mamdani_error do %>
          <div class="mb-4 flex items-center gap-3 rounded-lg border border-amber-900/50 bg-amber-950/30 px-4 py-3 text-sm text-amber-200">
            <span class="font-mono text-[10px] uppercase tracking-[0.2em] text-amber-400">
              inference offline
            </span>
            <span class="text-amber-100/80">
              {@mamdani_error}
              <%= if @mamdani_response do %>
                · showing last result
              <% end %>
            </span>
          </div>
        <% end %>

        <%= if @mamdani_crisp do %>
          <div class="mb-4 flex items-baseline gap-4 rounded-lg border border-white/5 bg-base-200 px-6 py-3">
            <span class="text-[10px] uppercase tracking-[0.2em] text-gray-500">
              Defuzzified output
            </span>
            <span class="text-xs font-medium text-gray-300">fan speed</span>
            <span class="font-mono text-2xl font-semibold tabular-nums text-amber-300">
              {format_number(@mamdani_crisp, 1)}
            </span>
            <span class="text-xs text-gray-500">% of max</span>
          </div>
        <% end %>

        <div class="rounded-lg bg-base-200 p-4">
          <div
            id="sandbox-mamdani-playground"
            phx-hook="MamdaniPlayground"
            phx-update="ignore"
            style="min-height: 640px;"
          >
          </div>
          <p class="mt-3 max-w-3xl text-xs leading-snug text-gray-500">
            Top row shows each input fuzzified into its term set, with a dashed
            crisp line and dots marking the degree of membership at that input.
            Middle shows each rule's firing strength — colored by the fan speed
            term it votes for. Bottom layers each rule's clipped consequent
            underneath the aggregated envelope; the white marker is the centroid.
          </p>
        </div>
      </section>
    </div>
    """
  end
end
