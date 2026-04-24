defmodule FugueWeb.MoodLive.ExperiencePanel do
  @moduledoc """
  Ambient overlay and slide-out detail panel for day focus on /mood.

  Replaces the former `MoodExperience` JS hook. State lives in the LiveView
  assigns (`selected_day`, `selected_cluster`, `analysis.cluster_colors`) and
  user interactions map to existing `handle_event` callbacks.
  """

  use Phoenix.Component

  @dimensions ~w(sleep anxiety sensitivity outlook speed)

  @dim_colors %{
    "sleep" => "#42c8e6",
    "anxiety" => "#e44dbc",
    "sensitivity" => "#a86ee6",
    "outlook" => "#6ee64d",
    "speed" => "#e6a542"
  }

  attr :selected_day, :map, default: nil
  attr :selected_cluster, :any, default: nil
  attr :cluster_colors, :map, default: %{}

  def ambient(assigns) do
    assigns = assign(assigns, :background, ambient_background(assigns))

    ~H"""
    <div
      class="mood-ambient"
      style={"position: fixed; inset: 0; pointer-events: none; z-index: 0; transition: opacity 1.2s ease, background 1.5s ease; opacity: #{if @background, do: 1, else: 0}; background: #{@background || "transparent"};"}
    >
    </div>
    """
  end

  attr :selected_day, :map, default: nil

  def panel(assigns) do
    assigns = assign(assigns, :dimensions, @dimensions)

    ~H"""
    <div
      class="mood-day-panel"
      style={"position: fixed; right: #{if @selected_day, do: "0px", else: "-380px"}; top: 0; bottom: 0; width: 360px; background: rgba(10, 10, 26, 0.95); border-left: 1px solid rgba(255,255,255,0.06); z-index: 50; padding: 20px; overflow-y: auto; transition: right 0.3s ease; backdrop-filter: blur(12px);"}
    >
      <%= if @selected_day do %>
        <button
          type="button"
          phx-click="clear_highlights"
          style="position: absolute; top: 12px; right: 16px; background: none; border: none; color: #666; font-size: 22px; cursor: pointer; line-height: 1;"
        >
          ×
        </button>

        <h3 style="color: #ccc; font-size: 18px; font-weight: 700; margin-bottom: 4px;">
          {@selected_day.date}
        </h3>

        <%= if @selected_day.dominant do %>
          <div style={"color: #{cluster_color(@selected_day, @selected_day.dominant.id)}; font-size: 13px; font-weight: 600; margin-bottom: 16px;"}>
            {@selected_day.dominant.name} — {percent(@selected_day.dominant.weight)}% membership
          </div>
        <% end %>

        <div style="color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">
          Dimensions
        </div>

        <%= for dim <- @dimensions, val = Map.get(@selected_day.dimensions || %{}, dim), val != nil do %>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
            <span style={"color: #{dim_color(dim)}; font-size: 11px; width: 72px; font-weight: 500;"}>
              {dim}
            </span>
            <div style="flex: 1; height: 6px; background: rgba(255,255,255,0.04); border-radius: 3px; position: relative;">
              <div style={"width: #{bar_pct(val)}%; height: 100%; background: #{dim_color(dim)}; border-radius: 3px; opacity: 0.7;"}>
              </div>
            </div>
            <span style="color: #888; font-size: 11px; min-width: 20px; text-align: right;">
              {val}
            </span>
          </div>
        <% end %>

        <%= if @selected_day.memberships && @selected_day.memberships != [] do %>
          <div style="color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin: 16px 0 8px;">
            Cluster membership
          </div>

          <%= for m <- @selected_day.memberships do %>
            <div
              phx-click="cluster_selected"
              phx-value-cluster={m.id}
              style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px; cursor: pointer;"
            >
              <span style={"display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #{cluster_color(@selected_day, m.id)};"}>
              </span>
              <span style={"color: #{cluster_color(@selected_day, m.id)}; font-size: 11px; flex: 1;"}>
                {m.name}
              </span>
              <span style="color: #888; font-size: 11px;">
                {percent(m.weight)}%
              </span>
            </div>
          <% end %>
        <% end %>

        <%= if @selected_day.prev || @selected_day.next do %>
          <div style="color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin: 16px 0 8px;">
            Neighbors
          </div>
          <.neighbor label="←" neighbor={@selected_day.prev} day={@selected_day} />
          <.neighbor label="→" neighbor={@selected_day.next} day={@selected_day} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :neighbor, :map, default: nil
  attr :day, :map, required: true

  defp neighbor(%{neighbor: nil} = assigns), do: ~H""

  defp neighbor(assigns) do
    ~H"""
    <div
      phx-click="day_selected"
      phx-value-date={@neighbor.date}
      style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px; cursor: pointer;"
    >
      <span style="color: #555; font-size: 11px; width: 14px;">{@label}</span>
      <span style="color: #999; font-size: 11px;">{@neighbor.date}</span>
      <span style={"color: #{cluster_color(@day, @neighbor.dominant_id)}; font-size: 11px; margin-left: auto;"}>
        {@neighbor.dominant_name || ""}
      </span>
    </div>
    """
  end

  # --- Helpers ---

  defp ambient_background(%{selected_day: %{dominant: %{id: id}} = day}) when not is_nil(id) do
    color = cluster_color(day, id)
    "radial-gradient(ellipse at 60% 40%, #{color}12 0%, transparent 70%)"
  end

  defp ambient_background(%{selected_cluster: cluster, cluster_colors: colors})
       when not is_nil(cluster) do
    color = Map.get(colors || %{}, cluster, "#333")
    "radial-gradient(ellipse at 60% 40%, #{color}12 0%, transparent 70%)"
  end

  defp ambient_background(_), do: nil

  defp cluster_color(%{cluster_colors: colors}, id), do: Map.get(colors || %{}, id, "#888")
  defp cluster_color(_, _), do: "#888"

  defp dim_color(dim), do: Map.get(@dim_colors, dim, "#888")

  defp percent(weight) when is_number(weight), do: round(weight * 100)
  defp percent(_), do: 0

  defp bar_pct(val) when is_number(val), do: min(val / 10 * 100, 100)
  defp bar_pct(_), do: 0
end
