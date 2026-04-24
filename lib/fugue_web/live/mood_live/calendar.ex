defmodule FugueWeb.MoodLive.Calendar do
  use FugueWeb, :live_component

  alias FugueWeb.MoodLive.CalendarGrid

  def render(assigns) do
    ~H"""
    <div class="calendar-section bg-base-200 rounded-lg p-4">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-lg font-semibold">Temporal Heatmap</h2>
        <%= if @highlighted_dates != [] or @selected_gap != nil do %>
          <button phx-click="clear_highlights" class="btn btn-xs btn-ghost">
            Clear selection
          </button>
        <% end %>
      </div>
      <div class="overflow-x-auto" style="min-height: 200px;">
        <CalendarGrid.grid
          days={@days}
          cluster_colors={@cluster_colors}
          cluster_names={@cluster_names}
          transition_dates={@transition_dates}
          highlighted_dates={@highlighted_dates}
          selected_gap={@selected_gap}
          selected_cluster={@selected_cluster}
        />
      </div>
    </div>
    """
  end
end
