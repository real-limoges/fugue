defmodule FugueWeb.LabLive.Gam do
  use FugueWeb, :live_view

  @datasets [
    %{
      id: "house_price",
      label: "Sale price vs floor area",
      title: "Floor area and sale price",
      blurb:
        "Sale prices against floor area, on a market that includes 700-square-foot starters and 4,500-square-foot custom builds. The mean rises with size, and so does the spread — a 4,000-sqft house has a lot more room to be cheap or expensive than a 700-sqft one does. A straight line gets the slope and loses everything else.",
      layers: [
        %{id: "linear", label: "— Linear", accent: :white_dash},
        %{id: "gam", label: "⌇ GAM (Normal)", accent: :gray},
        %{id: "gamlss", label: "◈ GAMLSS (Gamma)", accent: :primary}
      ],
      captions: [
        %{
          glyph: "—",
          accent: :white_dim,
          text:
            "A line averages a market that scatters very differently at each scale — off at the small end, off at the large end, indifferent about why."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the actual mean, but holds spread constant across the whole market. The gray band is the same width at 800 sqft as at 4,000 — wrong in both directions."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Gamma GAMLSS lets the spread ride along with the mean. The orange band fans out at the high end where prices genuinely vary, and tightens at the low end where they don't."
        }
      ]
    },
    %{
      id: "bay_bridge",
      label: "Bay Bridge tolls by hour",
      title: "Bay Bridge tolls by hour of day",
      blurb:
        "Cars per minute through the Bay Bridge toll plaza, four days stacked. Two peaks — commuting in around 8, commuting home around 5:30 — and a quiet midday. The peaks scatter way harder than the lulls: a Tuesday at 8am and a Saturday at 8am are different populations. Poisson and Negative Binomial disagree about how to admit that.",
      layers: [
        %{id: "linear", label: "— Linear (Poisson)", accent: :white_dash},
        %{id: "gam", label: "⌇ Poisson GAM", accent: :gray},
        %{id: "gamlss", label: "◈ NegBin GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "—",
          accent: :white_dim,
          text:
            "A log-linear fit through counts; it can't bend around two peaks, just slope between them."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Poisson GAM finds the bimodal shape, but Poisson forces variance equal to the mean. Its band is too tight at the peaks, where the day-to-day variation is actually much bigger."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Negative Binomial lets variance grow faster than the mean. The orange band widens at the peaks and the model stops surprising itself."
        }
      ]
    },
    %{
      id: "pizza",
      label: "Pizza delivery vs distance",
      title: "Pizza delivery time and distance",
      blurb:
        "Minutes from order to door, against miles of driving. Most deliveries follow a clean curve — fixed cooking time plus a few minutes per mile. The outliers are real: a driver got lost; the kitchen forgot; the route was empty at 11pm. Both directions, sometimes way out. (Pizza here is famously, persistently bad — the only thing more reliable than the curve is the disappointment at the end of it.)",
      layers: [
        %{id: "linear", label: "— Linear", accent: :white_dash},
        %{id: "gam", label: "⌇ Normal GAM", accent: :gray},
        %{id: "gamlss", label: "◈ Student-t GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "—",
          accent: :white_dim,
          text:
            "A straight line gets dragged off-center by the disaster runs and misses the slight nonlinearity at long distances."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the curve, but five wild deliveries persuade it to widen the band globally. Three-mile orders get the same uncertainty as the seven-mile ones."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Student-t expects the occasional disaster and treats it as a tail event. The orange band stays narrow where most deliveries actually behave."
        }
      ]
    },
    %{
      id: "shot_success",
      label: "Shot success vs distance",
      title: "Shooting accuracy and distance from the basket",
      blurb:
        "Shot success rate against distance from the rim. Layups go in almost every time; half-court heaves go in almost never. The response is a proportion, pinned to (0, 1) by definition. A Normal band can't see the walls and walks straight through them. Beta with a logit link knows where they are. (I have a Warriors season pass. Steph Curry, statistically, is not supposed to be making 35-footers. He keeps making 35-footers.)",
      layers: [
        %{id: "linear", label: "— Linear (Normal)", accent: :white_dash},
        %{id: "gam", label: "⌇ Normal GAM", accent: :gray},
        %{id: "gamlss", label: "◈ Beta GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "—",
          accent: :white_dim,
          text:
            "Linear regression doesn't know the response is bounded; it predicts negative shooting percentages and shrugs."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the shape, but its band can still punch through 0 or 1. Normal doesn't have edges built in."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Beta on a logit link respects the bounds. The orange band squeezes asymmetrically near 0 and 1 — when you're pinned against a wall, uncertainty stops being symmetric."
        }
      ]
    }
  ]

  @layer_ids ~w(linear gam gamlss)

  def mount(_params, _session, socket) do
    initial_id = "house_price"

    layer_state =
      for ds <- @datasets, into: %{} do
        {ds.id, Map.new(@layer_ids, &{&1, false})}
      end

    {:ok,
     socket
     |> assign(:datasets, @datasets)
     |> assign(:dataset_id, initial_id)
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

  def handle_event("select_dataset", %{"id" => id}, socket) do
    cond do
      id == socket.assigns.dataset_id ->
        {:noreply, socket}

      Enum.any?(@datasets, &(&1.id == id)) ->
        layers = socket.assigns.layer_state[id]

        {:noreply,
         socket
         |> assign(:dataset_id, id)
         |> push_event("lab_gam:set_dataset", %{dataset_id: id, layers: layers})}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_layer", %{"layer" => layer}, socket) when layer in @layer_ids do
    id = socket.assigns.dataset_id
    current = socket.assigns.layer_state[id]
    updated = Map.update!(current, layer, &(!&1))
    layer_state = Map.put(socket.assigns.layer_state, id, updated)

    {:noreply,
     socket
     |> assign(:layer_state, layer_state)
     |> push_event("lab_gam:set_layers", %{layers: updated})}
  end

  def render(assigns) do
    current = current_dataset(assigns)
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
    </div>
    """
  end

  defp current_dataset(assigns) do
    Enum.find(assigns.datasets, &(&1.id == assigns.dataset_id))
  end

  defp layer_button_classes(:white_dash, true), do: "border-white/40 text-white"
  defp layer_button_classes(:gray, true), do: "border-gray-400 text-gray-400"
  defp layer_button_classes(:primary, true), do: "border-primary/60 text-primary"
  defp layer_button_classes(_, false), do: "border-white/10 text-gray-600"

  defp caption_glyph_class(:white_dim), do: "text-white/40"
  defp caption_glyph_class(:gray), do: "text-gray-400"
  defp caption_glyph_class(:primary), do: "text-primary/70"
end
