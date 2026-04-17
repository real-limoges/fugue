defmodule FugueWeb.MenagerieLive.Fuzzy do
  @moduledoc """
  Triangular fuzzy membership bands over four years of Melbourne daily
  temperatures. Drag the sliders to reshape the bands and watch every day's
  partial memberships recompute.
  """

  use FugueWeb, :live_view

  alias Fugue.Menagerie.{Fuzzy, MelbourneWeather}

  @default_center_offset 0.0
  @default_spread 1.0

  @bands_lo 0.0
  @bands_hi 48.0

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
        last_date: last_date
      )

    {:ok, socket}
  end

  def handle_event("menagerie:bands_ready", _params, socket) do
    {:noreply, push_bands(socket)}
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

    shapes =
      Enum.map(mfs, fn mf ->
        %{
          name: mf.name,
          color: mf.color,
          peak: mf.b,
          samples: Fuzzy.sample_shape(mf, @bands_lo, @bands_hi)
        }
      end)

    push_event(socket, "update-bands", %{
      series: bands,
      mfs: Enum.map(mfs, fn mf -> %{name: mf.name, color: mf.color} end),
      shapes: shapes,
      bounds: [@bands_lo, @bands_hi]
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
    <div class="fuzzy-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Fuzzy temperature bands</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Hard categories lose the gradient. A 22°C day isn't exactly <em>mild</em>
          and exactly nothing else — it's mostly mild, a little cool, a little warm.
          Five overlapping triangular membership functions let every day hold partial
          membership in every fuzzy set at once.
        </p>
        <p class="text-xs text-gray-500 mt-3 max-w-3xl">
          Data: {@row_count} days of daily max temperatures from Melbourne Airport
          (GHCN-D {@first_date} → {@last_date}).
        </p>
      </div>

      <form phx-change="update_fuzzy_params" class="mb-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Center offset</span>
              <span class="text-xs font-mono text-gray-400">
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
              phx-throttle="80"
              class="range range-xs range-primary"
            />
            <p class="text-[11px] text-gray-500 mt-1">
              Shift all five peaks left or right along the temperature axis.
            </p>
          </label>

          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Spread</span>
              <span class="text-xs font-mono text-gray-400">
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
              phx-throttle="80"
              class="range range-xs range-primary"
            />
            <p class="text-[11px] text-gray-500 mt-1">
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
          id="menagerie-temperature-bands"
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
    </div>
    """
  end
end
