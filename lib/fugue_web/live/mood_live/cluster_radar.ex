defmodule FugueWeb.MoodLive.ClusterRadar do
  @moduledoc """
  Per-cluster radar charts of normalized dimension centroids.

  Replaces the former `ClusterRadar` JS hook. All geometry (grid rings, axis
  lines, data polygon vertices) is precomputed in Elixir; cluster-isolate
  dimming is driven by a CSS class on each radar cell.
  """

  use Phoenix.Component

  attr :centroids, :list, default: []
  attr :dimensions, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :selected_cluster, :any, default: nil

  def radars(assigns) do
    n = length(assigns.centroids)
    num_dims = length(assigns.dimensions)

    {size, font_size, label_font, col_pct} =
      cond do
        n <= 3 -> {210, "9px", "11px", 100 / max(n, 1)}
        n <= 5 -> {170, "9px", "11px", 33.333}
        n <= 6 -> {140, "7px", "10px", 33.333}
        true -> {140, "7px", "10px", 25.0}
      end

    radius = size / 2 - 40
    center = size / 2
    angle_slice = if num_dims > 0, do: :math.pi() * 2 / num_dims, else: 0

    # Shared grid geometry (same for every radar).
    ring_radii = for lvl <- 1..4, do: radius / 4 * lvl

    axes =
      Enum.with_index(assigns.dimensions)
      |> Enum.map(fn {dim, i} ->
        angle = angle_slice * i - :math.pi() / 2

        %{
          dim: dim,
          x2: :math.cos(angle) * radius,
          y2: :math.sin(angle) * radius,
          label_x: :math.cos(angle) * (radius + 16),
          label_y: :math.sin(angle) * (radius + 16)
        }
      end)

    cells =
      Enum.map(assigns.centroids, fn centroid ->
        color = Map.get(assigns.cluster_colors, centroid.id, "#666")

        points =
          Enum.with_index(assigns.dimensions)
          |> Enum.map(fn {dim, i} ->
            v = Map.get(centroid.values, dim, 0) * 1.0
            angle = angle_slice * i - :math.pi() / 2
            r = v * radius
            {:math.cos(angle) * r, :math.sin(angle) * r}
          end)

        polygon_d =
          points
          |> Enum.map_join(" ", fn {x, y} -> "#{fmt(x)},#{fmt(y)}" end)

        %{
          id: centroid.id,
          name: centroid.name,
          color: color,
          points: points,
          polygon_d: polygon_d,
          class:
            if(assigns.selected_cluster && centroid.id != assigns.selected_cluster,
              do: "radar-cell dim",
              else: "radar-cell"
            )
        }
      end)

    assigns =
      assign(assigns,
        cells: cells,
        ring_radii: ring_radii,
        axes: axes,
        size: size,
        center: center,
        font_size: font_size,
        label_font: label_font,
        flex_basis: "calc(#{fmt(col_pct)}% - 8px)"
      )

    ~H"""
    <div class="radar-grid">
      <%= for cell <- @cells do %>
        <div
          class={cell.class}
          data-cluster={cell.id}
          phx-click="cluster_selected"
          phx-value-cluster={cell.id}
          style={"flex: 0 0 #{@flex_basis}; max-width: #{@flex_basis};"}
        >
          <svg
            viewBox={"0 0 #{@size} #{@size}"}
            preserveAspectRatio="xMidYMid meet"
            style={"width: 100%; max-width: #{@size}px;"}
          >
            <g transform={"translate(#{@center},#{@center})"}>
              <%= for r <- @ring_radii do %>
                <circle r={fmt(r)} fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="0.5" />
              <% end %>

              <%= for ax <- @axes do %>
                <line
                  x1="0"
                  y1="0"
                  x2={fmt(ax.x2)}
                  y2={fmt(ax.y2)}
                  stroke="rgba(255,255,255,0.08)"
                  stroke-width="0.5"
                />
                <text
                  x={fmt(ax.label_x)}
                  y={fmt(ax.label_y)}
                  text-anchor="middle"
                  dominant-baseline="middle"
                  fill="#666"
                  font-size={@font_size}
                >
                  {ax.dim}
                </text>
              <% end %>

              <polygon
                points={cell.polygon_d}
                fill={cell.color}
                fill-opacity="0.15"
                stroke={cell.color}
                stroke-width="1.5"
              />

              <%= for {px, py} <- cell.points do %>
                <circle cx={fmt(px)} cy={fmt(py)} r="2.5" fill={cell.color} />
              <% end %>
            </g>
          </svg>
          <div
            class="radar-name"
            style={"color: #{cell.color}; font-size: #{@label_font};"}
            title={cell.name}
          >
            {cell.name}
          </div>
        </div>
      <% end %>

      <style>
        .radar-grid {
          display: flex; flex-wrap: wrap; gap: 6px; justify-content: center;
        }
        .radar-cell {
          text-align: center; cursor: pointer;
          transition: opacity 0.2s;
        }
        .radar-cell.dim { opacity: 0.2; }
        .radar-name {
          font-weight: 600; margin-top: 2px;
          white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
      </style>
    </div>
    """
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
