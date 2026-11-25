defmodule FugueWeb.MenagerieLive.Mamdani do
  @moduledoc """
  Mamdani fan controller. Two crisp inputs get fuzzified, seven rules
  fire server-side through `Fugue.Fuzzy` (ported from Hazy), and the
  aggregated output shape is defuzzified into a crisp fan speed.
  """

  use FugueWeb, :live_view

  import FugueWeb.IndexComponents, only: [menagerie_header: 1]

  alias Fugue.Fuzzy.Inference.Wire
  alias Fugue.Menagerie.Mamdani, as: MamdaniLogic
  import FugueWeb.MenagerieLive.Parse

  @impl true
  def mount(_params, _session, socket) do
    t = MamdaniLogic.default_temperature()
    h = MamdaniLogic.default_humidity()
    crisp = Wire.run_request(MamdaniLogic.request(t, h))["crisp"]["fan_speed"]

    # The chart's data waits for the hook's ready message (it needs a
    # mounted hook to receive it); the crisp readout doesn't.
    {:ok, assign(socket, mamdani_temperature: t, mamdani_humidity: h, mamdani_crisp: crisp)}
  end

  @impl true
  def handle_event("menagerie:mamdani_ready", _params, socket) do
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

  defp refresh_mamdani(socket) do
    %{mamdani_temperature: t, mamdani_humidity: h} = socket.assigns
    response = Wire.run_request(MamdaniLogic.request(t, h))
    apply_mamdani_result(socket, response, t, h)
  end

  defp apply_mamdani_result(socket, response, t, h) do
    rules =
      MamdaniLogic.rule_summaries()
      |> Enum.zip(response["rule_strengths"])
      |> Enum.map(fn {%{text: text, output_term: term}, strength} ->
        %{text: text, output_term: term, strength: strength}
      end)

    crisp = response["crisp"]

    socket
    |> assign(:mamdani_crisp, crisp["fan_speed"])
    |> push_event("update-mamdani", %{
      mfs: MamdaniLogic.mfs(),
      rules: rules,
      inputs: %{temperature: t, humidity: h},
      input_degrees: response["input_degrees"],
      output_curves: response["output_curves"],
      crisp: crisp
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mamdani-menagerie p-4 max-w-6xl mx-auto">
      <.menagerie_header title="Mamdani fan controller">
        <p class="text-sm text-base-content/60 mt-1 max-w-3xl leading-relaxed">
          An old-school rule of thumb: hot and humid, run the fan hard; cold,
          leave it off. Fuzzy control takes it more or less as-is. The temperature and humidity get read as how
          cold, warm or hot and how dry, comfortable or humid it is (all at once,
          in partial amounts), each of the seven rules fires about as hard as its
          conditions are true, and the fan speed is where their votes balance out
          (technically the centroid of the shape they make together, which is
          the bottom chart).
        </p>
        <p class="text-xs text-base-content/45 mt-3 max-w-3xl">
          The math runs server-side, in plain Elixir, in <code class="text-base-content/60">Fugue.Fuzzy</code>.
          Drag the sliders and watch which rules light up.
        </p>
      </.menagerie_header>

      <form id="mamdani-inputs" phx-change="update_mamdani_inputs" class="mb-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-base-content/75">Temperature</span>
              <span class="text-xs font-mono text-base-content/60">
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
              phx-throttle="80"
              class="range range-xs range-primary"
            />
            <p class="text-[11px] text-base-content/45 mt-1">
              Crisp temperature input, fuzzified into cold / warm / hot.
            </p>
          </label>

          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-base-content/75">Humidity</span>
              <span class="text-xs font-mono text-base-content/60">
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
              phx-throttle="80"
              class="range range-xs range-primary"
            />
            <p class="text-[11px] text-base-content/45 mt-1">
              Relative humidity, fuzzified into dry / comfortable / humid.
            </p>
          </label>
        </div>
      </form>

      <div class="mb-4 flex items-baseline gap-4 rounded-lg border border-base-content/5 bg-base-200 px-6 py-3">
        <span class="text-[10px] uppercase tracking-[0.2em] text-base-content/45">
          Defuzzified output
        </span>
        <span class="text-xs font-medium text-base-content/75">fan speed</span>
        <span
          class="font-mono text-2xl font-semibold tabular-nums"
          style="color: var(--menagerie-centroid-readout)"
        >
          {format_number(@mamdani_crisp, 1)}
        </span>
        <span class="text-xs text-base-content/45">% of max</span>
      </div>

      <div class="rounded-lg bg-base-200 p-4">
        <div
          id="menagerie-mamdani-playground"
          phx-hook="MamdaniPlayground"
          phx-update="ignore"
          style="min-height: 640px;"
        >
        </div>
        <.figure_source
          note="A full Mamdani controller: fuzzify, fire every rule, clip each consequent, aggregate the envelope, then defuzzify by centroid. The rule set is plain data, so changing a rule doesn't mean changing any code."
          repo={{"fugue", "lib/fugue/fuzzy/inference/mamdani.ex"}}
        />
        <p class="mt-3 max-w-3xl text-xs leading-snug text-base-content/45">
          Top row shows each input fuzzified into its term set, with a dashed
          crisp line and dots marking the degree of membership at that input.
          Middle shows each rule's firing strength, colored by the fan speed
          term it votes for. Bottom layers each rule's clipped consequent
          underneath the aggregated envelope; the line labeled "centroid" is the
          fan speed.
        </p>
      </div>

      <.source_link repos={[{"fugue", "lib/fugue/fuzzy/inference"}]} />
    </div>
    """
  end
end
