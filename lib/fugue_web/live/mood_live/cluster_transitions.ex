defmodule FugueWeb.MoodLive.ClusterTransitions do
  @moduledoc "Lists gap transitions where the dominant cluster changed."

  use FugueWeb, :live_component

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:expanded, fn -> true end)

    {:ok, socket}
  end

  def handle_event("toggle_transitions", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  def render(assigns) do
    transitions =
      assigns.gaps
      |> get_transitions()
      |> Enum.filter(&cluster_changed?/1)
      |> filter_by_cluster(assigns[:selected_cluster])
      |> Enum.sort_by(fn t -> t["gap"]["start"] end, :desc)

    assigns = assign(assigns, :transitions, transitions)

    ~H"""
    <div class="bg-base-200 rounded-lg p-4">
      <button
        phx-click="toggle_transitions"
        phx-target={@myself}
        class="flex items-center gap-1.5 text-lg font-semibold text-gray-300 hover:text-gray-100 w-full"
      >
        <span class={"inline-block transition-transform text-sm #{if @expanded, do: "rotate-90", else: ""}"}>
          &rsaquo;
        </span>
        Gap Transitions
        <span class="text-xs font-normal text-gray-500 ml-1">({length(@transitions)})</span>
      </button>

      <%= if @expanded do %>
        <div class="overflow-y-auto max-h-52 space-y-1 mt-3">
          <%= for t <- @transitions do %>
            <div
              phx-click="gap_selected"
              phx-value-start={t["gap"]["start"]}
              phx-value-length={t["gap"]["length"]}
              class={"flex items-center gap-2 px-2 py-1 rounded cursor-pointer text-sm hover:bg-base-300 #{if t["clusterChanged"], do: "border-l-2 border-warning", else: ""}"}
            >
              <span class="text-gray-400 w-24 shrink-0">{t["gap"]["start"]}</span>
              <span class="text-gray-500 w-12 shrink-0">{t["gap"]["length"]}d</span>
              <div class="flex items-center gap-1 flex-1 min-w-0">
                <%= for {cluster, _mem} <- top_cluster(t["before"]) do %>
                  <span
                    class="px-1.5 py-0.5 rounded text-xs"
                    style={"background: #{Map.get(@cluster_colors, cluster, "#666")}33; color: #{Map.get(@cluster_colors, cluster, "#aaa")}"}
                  >
                    {Map.get(@cluster_names, cluster, cluster)}
                  </span>
                <% end %>
                <span class="text-gray-500">&rarr;</span>
                <%= for {cluster, _mem} <- top_cluster(t["after"]) do %>
                  <span
                    class="px-1.5 py-0.5 rounded text-xs"
                    style={"background: #{Map.get(@cluster_colors, cluster, "#666")}33; color: #{Map.get(@cluster_colors, cluster, "#aaa")}"}
                  >
                    {Map.get(@cluster_names, cluster, cluster)}
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_transitions(nil), do: []
  defp get_transitions(%{transitions: t}), do: t
  defp get_transitions(_), do: []

  defp filter_by_cluster(transitions, nil), do: transitions

  defp filter_by_cluster(transitions, cluster) do
    Enum.filter(transitions, fn t ->
      before = t["before"] || %{}
      after_m = t["after"] || %{}
      Map.get(before, cluster, 0) >= 0.3 or Map.get(after_m, cluster, 0) >= 0.3
    end)
  end

  defp cluster_changed?(t) do
    top_before = top_cluster_key(t["before"])
    top_after = top_cluster_key(t["after"])
    top_before != top_after
  end

  defp top_cluster_key(nil), do: nil

  defp top_cluster_key(memberships) when is_map(memberships) do
    case Enum.max_by(memberships, fn {_k, v} -> v end, fn -> nil end) do
      {k, _v} -> k
      nil -> nil
    end
  end

  defp top_cluster(nil), do: []

  defp top_cluster(memberships) when is_map(memberships) do
    memberships
    |> Enum.sort_by(fn {_k, v} -> v end, :desc)
    |> Enum.take(1)
  end
end
