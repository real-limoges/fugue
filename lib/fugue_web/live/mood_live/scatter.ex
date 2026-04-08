defmodule FugueWeb.MoodLive.ScatterPlot do
  use FugueWeb, :live_component

  @dimensions ~w(sleep anxiety sensitivity outlook speed)

  def render(assigns) do
    assigns = assign(assigns, :dimensions, @dimensions)

    ~H"""
    <div class="scatter-section bg-base-200 rounded-lg p-4">
      <h2 class="text-lg font-semibold mb-3">Scatter Plot</h2>

      <div class="flex gap-4 mb-3">
        <form phx-change="update_x_axis">
          <label class="text-sm font-medium">X Axis</label>
          <select name="value" class="select select-sm select-bordered ml-2">
            <%= for dim <- @dimensions do %>
              <option value={dim} selected={dim == @scatter_x}>{String.capitalize(dim)}</option>
            <% end %>
            <%= for cluster <- @clusters do %>
              <option value={"membership:" <> cluster["id"]}
                selected={("membership:" <> cluster["id"]) == @scatter_x}>
                {cluster["name"]} membership
              </option>
            <% end %>
          </select>
        </form>
        <form phx-change="update_y_axis">
          <label class="text-sm font-medium">Y Axis</label>
          <select name="value" class="select select-sm select-bordered ml-2">
            <%= for dim <- @dimensions do %>
              <option value={dim} selected={dim == @scatter_y}>{String.capitalize(dim)}</option>
            <% end %>
            <%= for cluster <- @clusters do %>
              <option value={"membership:" <> cluster["id"]}
                selected={("membership:" <> cluster["id"]) == @scatter_y}>
                {cluster["name"]} membership
              </option>
            <% end %>
          </select>
        </form>
      </div>

      <div id="scatter-plot"
        phx-hook="ScatterPlot"
        phx-update="ignore"
        style="min-height: 400px;">
      </div>
    </div>
    """
  end
end
