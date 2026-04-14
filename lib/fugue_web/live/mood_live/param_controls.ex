defmodule FugueWeb.MoodLive.ParamControls do
  use FugueWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="param-controls bg-base-200 rounded-lg p-4">
      <h2 class="text-lg font-semibold mb-3">Clustering Parameters</h2>

      <form phx-change="update_params" phx-debounce="500">
        <div class="flex flex-wrap gap-6 items-end">
          <div class="flex-1 min-w-48">
            <label class="block text-sm font-medium mb-1">
              Clusters (k): <span class="text-primary">{@k}</span>
            </label>
            <input
              type="range"
              name="k"
              value={@k}
              min="2"
              max="5"
              step="1"
              class="range range-primary range-sm w-full"
            />
          </div>

          <div class="flex-1 min-w-48">
            <label class="block text-sm font-medium mb-1">
              Fuzziness (m):
              <span class="text-primary">{:erlang.float_to_binary(@m, decimals: 1)}</span>
            </label>
            <input
              type="range"
              name="m"
              value={@m}
              min="1.1"
              max="3.0"
              step="0.1"
              class="range range-secondary range-sm w-full"
            />
          </div>

          <div class="flex gap-4 text-sm text-gray-400">
            <span>Clusters: <strong class="text-white">{@cluster_count}</strong></span>
            <%= if @fpc do %>
              <span>FPC: <strong class="text-white">{Float.round(@fpc, 3)}</strong></span>
            <% end %>
            <%= if @iterations do %>
              <span>Iterations: <strong class="text-white">{@iterations}</strong></span>
            <% end %>
          </div>
        </div>
      </form>
    </div>
    """
  end
end
