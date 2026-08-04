defmodule FugueWeb.MenagerieLive.Mamdani do
  @moduledoc """
  Mamdani fan controller. Two crisp inputs get fuzzified, seven rules
  fire server-side through `Fugue.Fuzzy` (ported from Hazy), and the
  aggregated output shape is defuzzified into a crisp fan speed.
  """

  use FugueWeb, :live_view

  alias Fugue.Fuzzy.Inference.Wire
  alias Fugue.Menagerie.Mamdani, as: MamdaniLogic

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        mamdani_temperature: MamdaniLogic.default_temperature(),
        mamdani_humidity: MamdaniLogic.default_humidity(),
        mamdani_response: nil,
        mamdani_crisp: nil
      )

    {:ok, socket}
  end

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
    |> assign(mamdani_response: response, mamdani_crisp: crisp["fan_speed"])
    |> push_event("update-mamdani", %{
      mfs: MamdaniLogic.mfs(),
      rules: rules,
      inputs: %{temperature: t, humidity: h},
      input_degrees: response["input_degrees"],
      output_curves: response["output_curves"],
      crisp: crisp
    })
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
    <div class="mamdani-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Mamdani fan controller</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          An old-school rule of thumb, wired up as a fuzzy controller: if it's hot
          and humid, run the fan hard; if it's cold, leave it off. Two crisp inputs
          get fuzzified into overlapping term sets, seven rules fire with varying
          strength, the output terms get clipped and aggregated, and the centroid
          of that aggregated shape is the crisp fan speed.
        </p>
        <p class="text-xs text-gray-500 mt-3 max-w-3xl">
          Math runs server-side through <code class="text-gray-400">Fugue.Fuzzy</code>
          (ported from Hazy, the Haskell fuzzy-logic library this used to call out to
          over HTTP). Drag the sliders to watch the rule firings, output shape, and
          defuzzified crisp value respond.
        </p>
      </div>

      <form phx-change="update_mamdani_inputs" class="mb-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Temperature</span>
              <span class="text-xs font-mono text-gray-400">
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
            <p class="text-[11px] text-gray-500 mt-1">
              Crisp temperature input, fuzzified into cold / warm / hot.
            </p>
          </label>

          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Humidity</span>
              <span class="text-xs font-mono text-gray-400">
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
            <p class="text-[11px] text-gray-500 mt-1">
              Relative humidity, fuzzified into dry / comfortable / humid.
            </p>
          </label>
        </div>
      </form>

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
          id="menagerie-mamdani-playground"
          phx-hook="MamdaniPlayground"
          phx-update="ignore"
          style="min-height: 640px;"
        >
        </div>
        <p class="mt-3 max-w-3xl text-xs leading-snug text-gray-500">
          Top row shows each input fuzzified into its term set, with a dashed
          crisp line and dots marking the degree of membership at that input.
          Middle shows each rule's firing strength, colored by the fan speed
          term it votes for. Bottom layers each rule's clipped consequent
          underneath the aggregated envelope; the white marker is the centroid.
        </p>
      </div>
    </div>
    """
  end
end
