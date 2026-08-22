defmodule FugueWeb.MenagerieLive.AnimatedCard do
  @moduledoc """
  Shared seam for animated menagerie cards (see `CONTEXT.md`).

  An animated card owns parameter state in its LiveView, declares a list
  of `%Slider{}` config structs, and pushes parameter changes to a JS
  canvas hook via `push_event`. This module concentrates the parts that
  were previously copy-pasted across cards:

    * parameter parsing, clamping, and casting from a `phx-change` form
    * the `update_params` / `reset` event-handler shape
    * the slider grid render

  Cards still own their own `mount`, render shell (nav, h1, description,
  canvas, any non-slider controls), and any card-specific event handlers
  (e.g. `boids` presets, `sandpile` mode toggle).

  ## Usage

      defmodule FugueWeb.MenagerieLive.MyCard do
        use FugueWeb, :live_view
        alias FugueWeb.MenagerieLive.AnimatedCard
        alias FugueWeb.MenagerieLive.AnimatedCard.Slider

        @defaults %{"speed" => 10, "count" => 50}

        @sliders [
          Slider.new(key: "speed", label: "Speed", min: 1, max: 200, cast: &trunc/1),
          Slider.new(key: "count", label: "Count", min: 10, max: 200, cast: &trunc/1)
        ]

        def mount(_, _, socket),
          do: {:ok, assign(socket, params: @defaults, sliders: @sliders)}

        def handle_event("update_params", form, socket),
          do: AnimatedCard.handle_update_params(form, socket, @sliders, "mycard:set_params")

        def handle_event("reset", _, socket),
          do: AnimatedCard.handle_reset(socket, @defaults, "mycard:set_params")

        def render(assigns), do: ~H\"\"\"
          ...
          <AnimatedCard.slider_grid sliders={@sliders} params={@params} />
          \"\"\"
      end

  See also: `mamdani` is intentionally *not* an animated card and does
  not use this seam.
  """

  use Phoenix.Component

  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  @doc """
  Parses a `phx-change` form payload into a new params map. For each
  slider, the matching form value is run through `Float.parse/1`,
  clamped to `[min, max]`, then through the slider's `cast`. Form keys
  that aren't in the slider list are ignored. Sliders whose key is
  absent from the form leave the param unchanged.
  """
  @spec parse_params(map(), map(), [Slider.t()]) :: map()
  def parse_params(form, current, sliders) when is_map(form) and is_list(sliders) do
    Enum.reduce(sliders, current, fn %Slider{key: key, min: lo, max: hi, cast: cast}, acc ->
      case Map.fetch(form, key) do
        {:ok, raw} ->
          val = raw |> parse_number(current[key]) |> clamp(lo, hi) |> cast.()
          Map.put(acc, key, val)

        :error ->
          acc
      end
    end)
  end

  @doc """
  Handles the canonical `update_params` event: parse form, short-circuit
  if nothing changed, otherwise assign + push the event with the full
  param map. Returns the standard `{:noreply, socket}` tuple.
  """
  def handle_update_params(form, socket, sliders, event_name)
      when is_binary(event_name) do
    new_params = parse_params(form, socket.assigns.params, sliders)

    if new_params == socket.assigns.params do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:params, new_params)
       |> Phoenix.LiveView.push_event(event_name, new_params)}
    end
  end

  @doc """
  Handles the canonical `reset` event: assign defaults + push them under
  `event_name`. Most cards push the same event for reset as for update
  (so the JS hook has one entry point).
  """
  def handle_reset(socket, defaults, event_name) when is_binary(event_name) do
    {:noreply,
     socket
     |> assign(:params, defaults)
     |> Phoenix.LiveView.push_event(event_name, defaults)}
  end

  attr :sliders, :list, required: true, doc: "List of `%Slider{}` configs."
  attr :params, :map, required: true, doc: "Current param map keyed by slider key."

  attr :class, :string,
    default: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4",
    doc: "Tailwind classes for the form layout."

  @doc """
  Renders the form of slider inputs. Wires `phx-change="update_params"`;
  cards using this component must implement that event (typically by
  delegating to `handle_update_params/4`).
  """
  def slider_grid(assigns) do
    ~H"""
    <form phx-change="update_params" class={@class}>
      <label :for={slider <- @sliders} class="block bg-base-200 rounded-lg p-3">
        <div class="flex items-center justify-between mb-1">
          <span class="text-xs font-semibold text-base-content/75">{slider.label}</span>
          <span class="text-xs font-mono text-base-content/60">
            {slider.format.(@params[slider.key])}
          </span>
        </div>
        <input
          type="range"
          name={slider.key}
          min={slider.min}
          max={slider.max}
          step={slider.step}
          value={@params[slider.key]}
          class="range range-xs range-primary"
        />
      </label>
    </form>
    """
  end

  defp parse_number(raw, fallback) when is_binary(raw) do
    case Float.parse(raw) do
      {val, _} -> val
      :error -> fallback
    end
  end

  defp clamp(val, lo, hi), do: val |> max(lo) |> min(hi)
end
