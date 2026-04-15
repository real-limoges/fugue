defmodule FugueWeb.MoodLive.MoodTransitions do
  @moduledoc "Lists day-to-day transitions between dominant mood clusters."

  use FugueWeb, :live_component

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:expanded, fn -> true end)

    {:ok, socket}
  end

  def handle_event("toggle_list", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  def render(assigns) do
    transitions =
      assigns.transitions
      |> filter_by_cluster(assigns[:selected_cluster])
      |> Enum.sort_by(fn t -> t.date end, :desc)

    assigns = assign(assigns, :filtered, transitions)

    ~H"""
    <div class="bg-base-200 rounded-lg p-4 h-full flex flex-col overflow-hidden">
      <button
        phx-click="toggle_list"
        phx-target={@myself}
        class="flex items-center gap-1.5 text-lg font-semibold text-gray-300 hover:text-gray-100 w-full"
      >
        <span class={"inline-block transition-transform text-sm #{if @expanded, do: "rotate-90", else: ""}"}>
          &rsaquo;
        </span>
        Mood Transitions
        <span class="text-xs font-normal text-gray-500 ml-1">({length(@filtered)})</span>
      </button>

      <%= if @expanded do %>
        <div
          id={"mood-transitions-list-rows-#{@myself}"}
          class="flex-1 overflow-y-auto min-h-0 space-y-1 mt-3"
        >
          <%= for t <- @filtered do %>
            <div
              phx-click="day_selected"
              phx-value-date={t.date}
              data-date={t.date}
              class={"flex items-center gap-2 px-2 py-1 rounded cursor-pointer text-sm transition-colors #{if t.date in (@highlighted_dates || []), do: "bg-amber-300/15 ring-1 ring-amber-300/60", else: "hover:bg-base-300"}"}
            >
              <span class="text-gray-400 w-24 shrink-0">{t.date}</span>
              <div class="flex items-center gap-1 flex-1 min-w-0">
                <span
                  class="px-1.5 py-0.5 rounded text-xs"
                  style={"background: #{Map.get(@cluster_colors, t.from, "#666")}33; color: #{Map.get(@cluster_colors, t.from, "#aaa")}"}
                >
                  {Map.get(@cluster_names, t.from, t.from)}
                </span>
                <span class="text-gray-500">&rarr;</span>
                <span
                  class="px-1.5 py-0.5 rounded text-xs"
                  style={"background: #{Map.get(@cluster_colors, t.to, "#666")}33; color: #{Map.get(@cluster_colors, t.to, "#aaa")}"}
                >
                  {Map.get(@cluster_names, t.to, t.to)}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp filter_by_cluster(transitions, nil), do: transitions

  defp filter_by_cluster(transitions, cluster) do
    Enum.filter(transitions, fn t ->
      t.from == cluster or t.to == cluster
    end)
  end
end
