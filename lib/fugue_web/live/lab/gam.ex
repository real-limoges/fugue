defmodule FugueWeb.LabLive.Gam do
  @moduledoc """
  `/lab/gam`: four scatter datasets, each fit by a line, a GAM, and a
  GAMLSS. The chart itself is a JS hook (drag-to-edit interactivity);
  this module owns dataset selection and per-dataset layer toggles.
  """

  use FugueWeb, :live_view

  alias FugueWeb.LabLive.GamDatasets

  @layer_ids ~w(linear gam gamlss)
  @initial_dataset "house_price"

  def mount(_params, _session, socket) do
    layer_state =
      for ds <- GamDatasets.all(), into: %{} do
        {ds.id, Map.new(@layer_ids, &{&1, false})}
      end

    {:ok,
     socket
     |> assign(:datasets, GamDatasets.all())
     |> assign(:dataset_id, @initial_dataset)
     |> assign(:layer_state, layer_state)}
  end

  def handle_event("lab_gam:ready", _, socket) do
    id = socket.assigns.dataset_id

    {:noreply,
     push_event(socket, "lab_gam:set_dataset", %{
       dataset_id: id,
       layers: socket.assigns.layer_state[id]
     })}
  end

  def handle_event("select_dataset", %{"id" => id}, socket)
      when id != socket.assigns.dataset_id do
    case GamDatasets.fetch(id) do
      {:ok, _} ->
        layers = socket.assigns.layer_state[id]

        {:noreply,
         socket
         |> assign(:dataset_id, id)
         |> push_event("lab_gam:set_dataset", %{dataset_id: id, layers: layers})}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("select_dataset", _, socket), do: {:noreply, socket}

  def handle_event("toggle_layer", %{"layer" => layer}, socket) when layer in @layer_ids do
    id = socket.assigns.dataset_id
    updated = Map.update!(socket.assigns.layer_state[id], layer, &(!&1))
    layer_state = Map.put(socket.assigns.layer_state, id, updated)

    {:noreply,
     socket
     |> assign(:layer_state, layer_state)
     |> push_event("lab_gam:set_layers", %{layers: updated})}
  end

  def render(assigns) do
    {:ok, current} = GamDatasets.fetch(assigns.dataset_id)
    layers = assigns.layer_state[assigns.dataset_id]
    assigns = assign(assigns, current: current, layers: layers)

    ~H"""
    <div class="p-6 max-w-4xl mx-auto">
      <div class="mb-6 flex flex-wrap gap-2">
        <button
          :for={ds <- @datasets}
          phx-click="select_dataset"
          phx-value-id={ds.id}
          class={[
            "btn btn-xs btn-ghost border font-mono text-xs",
            (ds.id == @dataset_id && "border-primary/70 text-primary bg-primary/10") ||
              "border-white/25 text-gray-300 hover:text-white hover:border-white/40"
          ]}
        >
          {ds.label}
        </button>
      </div>

      <h1 class="text-2xl font-semibold text-white mb-1">{@current.title}</h1>
      <p class="text-gray-400 text-sm mb-6">
        {@current.blurb}
      </p>

      <div
        id="gam-viz"
        phx-hook="LabGam"
        phx-update="ignore"
        data-dataset-id={@dataset_id}
        class="w-full rounded-lg bg-base-200"
        style="min-height: 420px;"
      />

      <.figure_source
        note="Penalized splines fit by REML in Rust, compiled to WASM and loaded on demand. Switching family or dataset refits in the tab; there is no model server behind this."
        repo="glissando"
      />

      <div class="mt-4 flex flex-wrap gap-3">
        <button
          :for={layer <- @current.layers}
          phx-click="toggle_layer"
          phx-value-layer={layer.id}
          class={[
            "btn btn-xs btn-ghost border",
            layer_button_classes(layer.accent, @layers[layer.id])
          ]}
        >
          {layer.label}
        </button>
      </div>

      <div class="mt-5 space-y-1 text-xs text-gray-500 font-mono">
        <p :for={cap <- @current.captions}>
          <span class={caption_glyph_class(cap.accent)}>{cap.glyph}</span>
          {cap.text}
        </p>
      </div>

      <.source_link repos={["glissando", {"fugue", "lib/fugue_web/live/lab/gam.ex"}]} />
    </div>
    """
  end

  defp layer_button_classes(:white_dash, true), do: "border-white/40 text-white"
  defp layer_button_classes(:gray, true), do: "border-gray-400 text-gray-400"
  defp layer_button_classes(:primary, true), do: "border-primary/60 text-primary"
  defp layer_button_classes(_, false), do: "border-white/10 text-gray-600"

  defp caption_glyph_class(:white_dim), do: "text-white/40"
  defp caption_glyph_class(:gray), do: "text-gray-400"
  defp caption_glyph_class(:primary), do: "text-primary/70"
end
