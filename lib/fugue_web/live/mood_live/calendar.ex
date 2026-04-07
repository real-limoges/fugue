defmodule FugueWeb.MoodLive.Calendar do
  use FugueWeb, :live_component

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
      <div id="calendar-heatmap"
        phx-hook="CalendarHeatmap"
        phx-update="ignore"
        class="overflow-x-auto"
        style="min-height: 200px;">
      </div>
    </div>
    """
  end
end
