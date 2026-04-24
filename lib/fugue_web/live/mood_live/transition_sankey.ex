defmodule FugueWeb.MoodLive.TransitionSankey do
  @moduledoc """
  Sankey flow diagram of cluster → cluster transitions. Replaces the former
  `TransitionSankey` JS hook: node layout, link geometry, and isolate dimming
  are all computed server-side.
  """

  use Phoenix.Component

  @width 700
  @height 280
  @m_top 30
  @m_right 15
  @m_bottom 10
  @m_left 20
  @inner_w @width - @m_left - @m_right
  @inner_h @height - @m_top - @m_bottom
  @node_w 14
  @node_pad 6

  attr :transitions, :list, default: []
  attr :cluster_ids, :list, default: []
  attr :cluster_names, :map, default: %{}
  attr :cluster_colors, :map, default: %{}
  attr :selected_cluster, :any, default: nil

  def sankey(assigns) do
    layout = build_layout(assigns.transitions, assigns.cluster_ids)

    links =
      Enum.map(layout.links, fn link ->
        color = Map.get(assigns.cluster_colors, link.to, "#666")

        Map.merge(link, %{
          color: color,
          class: link_class(link, assigns.selected_cluster)
        })
      end)

    left_nodes =
      Enum.map(layout.left_nodes, fn n ->
        color = Map.get(assigns.cluster_colors, n.id, "#666")
        name = Map.get(assigns.cluster_names, n.id, n.id)

        Map.merge(n, %{
          color: color,
          name: name,
          label_x: n.x + @node_w + 5,
          anchor: "start",
          class: node_class(n.id, assigns.selected_cluster)
        })
      end)

    right_nodes =
      Enum.map(layout.right_nodes, fn n ->
        color = Map.get(assigns.cluster_colors, n.id, "#666")
        name = Map.get(assigns.cluster_names, n.id, n.id)

        Map.merge(n, %{
          color: color,
          name: name,
          label_x: n.x - 5,
          anchor: "end",
          class: node_class(n.id, assigns.selected_cluster)
        })
      end)

    assigns =
      assign(assigns,
        links: links,
        left_nodes: left_nodes,
        right_nodes: right_nodes,
        any?: layout.left_nodes != [] or layout.right_nodes != [],
        svg_width: @width,
        svg_height: @height,
        node_w: @node_w,
        g_transform: "translate(#{@m_left},#{@m_top})",
        from_label_x: @m_left + @node_w / 2,
        to_label_x: @m_left + @inner_w - @node_w / 2
      )

    ~H"""
    <div id="transition-sankey" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%;"
      >
        <%= if @any? do %>
          <text x={fmt(@from_label_x)} y="14" text-anchor="middle" fill="#555" font-size="10px">
            from
          </text>
          <text x={fmt(@to_label_x)} y="14" text-anchor="middle" fill="#555" font-size="10px">
            to
          </text>
        <% end %>

        <g transform={@g_transform}>
          <%= for link <- @links do %>
            <path
              class={link.class}
              data-from={link.from}
              data-to={link.to}
              d={link.d}
              fill={link.color}
              stroke={link.color}
            />
          <% end %>

          <%= for n <- @left_nodes ++ @right_nodes do %>
            <rect
              class={n.class}
              data-cluster={n.id}
              x={fmt(n.x)}
              y={fmt(n.y)}
              width={@node_w}
              height={fmt(n.h)}
              rx="2"
              fill={n.color}
              phx-click="cluster_selected"
              phx-value-cluster={n.id}
              style="cursor: pointer;"
            />
            <text
              class={"sankey-label " <> (if n.class =~ "dim", do: "dim", else: "")}
              data-cluster={n.id}
              x={fmt(n.label_x)}
              y={fmt(n.y + n.h / 2)}
              text-anchor={n.anchor}
              dominant-baseline="middle"
              fill={n.color}
              font-size="9px"
              font-weight="500"
              phx-click="cluster_selected"
              phx-value-cluster={n.id}
              style="cursor: pointer;"
            >
              {n.name}
            </text>
          <% end %>
        </g>
      </svg>

      <style>
        .sankey-link { fill-opacity: 0.25; stroke-width: 0.5; stroke-opacity: 0.15; transition: fill-opacity 0.2s, stroke-opacity 0.2s; }
        .sankey-link.highlight { fill-opacity: 0.4; stroke-opacity: 0.3; }
        .sankey-link.dim { fill-opacity: 0.04; stroke-opacity: 0.03; }
        .sankey-node { fill-opacity: 0.7; transition: fill-opacity 0.2s; }
        .sankey-node.highlight { fill-opacity: 0.9; }
        .sankey-node.dim { fill-opacity: 0.15; }
        .sankey-label.dim { opacity: 0.25; }
      </style>
    </div>
    """
  end

  # --- Layout ---

  defp build_layout(transitions, cluster_ids) do
    flow_counts =
      Enum.reduce(transitions, %{}, fn t, acc ->
        Map.update(acc, {t.from, t.to}, 1, &(&1 + 1))
      end)

    active_from = MapSet.new(transitions, & &1.from)
    active_to = MapSet.new(transitions, & &1.to)

    active_ids =
      Enum.filter(
        cluster_ids,
        &(MapSet.member?(active_from, &1) or MapSet.member?(active_to, &1))
      )

    if active_ids == [] do
      %{left_nodes: [], right_nodes: [], links: []}
    else
      {from_totals, to_totals} = totals(flow_counts)

      left_ids = Enum.filter(active_ids, &Map.has_key?(from_totals, &1))
      right_ids = Enum.filter(active_ids, &Map.has_key?(to_totals, &1))

      left_nodes = layout_nodes(left_ids, from_totals, 0)
      right_nodes = layout_nodes(right_ids, to_totals, @inner_w - @node_w)

      left_map = Map.new(left_nodes, &{&1.id, &1})
      right_map = Map.new(right_nodes, &{&1.id, &1})

      {_, _, links} =
        flow_counts
        |> Enum.map(fn {{f, t}, c} -> %{from: f, to: t, count: c} end)
        |> Enum.sort_by(& &1.count, :desc)
        |> Enum.reduce({%{}, %{}, []}, fn link, {l_off, r_off, acc} ->
          ln = Map.get(left_map, link.from)
          rn = Map.get(right_map, link.to)

          if is_nil(ln) or is_nil(rn) do
            {l_off, r_off, acc}
          else
            from_total = Map.get(from_totals, link.from, 1)
            to_total = Map.get(to_totals, link.to, 1)
            lh = link.count / from_total * ln.h
            rh = link.count / to_total * rn.h
            ly = ln.y + Map.get(l_off, link.from, 0)
            ry = rn.y + Map.get(r_off, link.to, 0)

            x0 = @node_w
            x1 = @inner_w - @node_w
            mx = (x0 + x1) / 2

            d =
              "M#{fmt(x0)},#{fmt(ly)} " <>
                "C#{fmt(mx)},#{fmt(ly)} #{fmt(mx)},#{fmt(ry)} #{fmt(x1)},#{fmt(ry)} " <>
                "L#{fmt(x1)},#{fmt(ry + rh)} " <>
                "C#{fmt(mx)},#{fmt(ry + rh)} #{fmt(mx)},#{fmt(ly + lh)} #{fmt(x0)},#{fmt(ly + lh)} Z"

            new_l_off = Map.update(l_off, link.from, lh, &(&1 + lh))
            new_r_off = Map.update(r_off, link.to, rh, &(&1 + rh))

            {new_l_off, new_r_off, [Map.put(link, :d, d) | acc]}
          end
        end)

      %{
        left_nodes: left_nodes,
        right_nodes: right_nodes,
        links: Enum.reverse(links)
      }
    end
  end

  defp totals(flow_counts) do
    Enum.reduce(flow_counts, {%{}, %{}}, fn {{f, t}, c}, {from_acc, to_acc} ->
      {Map.update(from_acc, f, c, &(&1 + c)), Map.update(to_acc, t, c, &(&1 + c))}
    end)
  end

  defp layout_nodes([], _, _), do: []

  defp layout_nodes(ids, totals, x_pos) do
    total_size = Enum.reduce(ids, 0, fn id, s -> s + Map.get(totals, id, 0) end)
    avail_h = @inner_h - (length(ids) - 1) * @node_pad

    {nodes, _} =
      Enum.reduce(ids, {[], 0.0}, fn id, {acc, y_off} ->
        h = max(Map.get(totals, id, 0) / total_size * avail_h, 8.0)
        node = %{id: id, x: x_pos, y: y_off, h: h}
        {[node | acc], y_off + h + @node_pad}
      end)

    Enum.reverse(nodes)
  end

  defp link_class(_link, nil), do: "sankey-link"

  defp link_class(%{from: f, to: t}, cluster) do
    if f == cluster or t == cluster, do: "sankey-link highlight", else: "sankey-link dim"
  end

  defp node_class(_id, nil), do: "sankey-node"
  defp node_class(id, id), do: "sankey-node highlight"
  defp node_class(_id, _selected), do: "sankey-node dim"

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
