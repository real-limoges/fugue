defmodule FugueWeb.GraphLive do
  use FugueWeb, :live_view
  require Logger
  alias Fugue.Graph.{BlomEncoder, Loader}

  # Topic slug → seed article id. Hardcoded to skip the ~3s linear title
  # scan on every click (there's no title index on the Dedalus-built DB).
  @topics %{
    "rust_programming" => {29_414_838, "Rust (programming language)"},
    "functional_programming" => {10_933, "Functional programming"}
  }

  def mount(_params, _session, socket) do
    Logger.info("GraphLive.mount connected=#{connected?(socket)}")

    socket =
      socket
      |> assign(:topics, Map.keys(@topics))
      |> assign(:current_topic, nil)
      |> assign(:search_query, "")
      |> assign(:node_count, 0)
      |> assign(:selected_node, nil)
      |> assign(:loading, false)

    # On the websocket mount, kick off the default topic so the graph is
    # already loading while the client finishes pulling the WASM module.
    # `send/2` to self defers work until after mount returns, keeping the
    # initial render fast.
    if connected?(socket) do
      send(self(), {:load_topic, default_topic()})
      {:ok, assign(socket, :loading, true)}
    else
      {:ok, socket}
    end
  end

  defp default_topic, do: "rust_programming"

  def handle_event("load_topic", %{"topic" => topic}, socket) do
    send(self(), {:load_topic, topic})
    {:noreply, assign(socket, loading: true, current_topic: topic)}
  end

  def handle_event("search", %{"value" => query}, socket) do
    cond do
      socket.assigns.current_topic == nil ->
        {:noreply, socket}

      query == "" ->
        {:noreply, assign(socket, :search_query, "")}

      true ->
        case Loader.search_articles(query) do
          {:ok, matching_ids} ->
            {:noreply,
             socket
             |> assign(:search_query, query)
             |> push_event("highlight-nodes", %{node_ids: matching_ids})}

          {:error, reason} ->
            Logger.warning("search_articles failed: #{inspect(reason)}")
            {:noreply, assign(socket, :search_query, query)}
        end
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    case Loader.get_article(id) do
      {:ok, article} ->
        {:noreply, assign(socket, :selected_node, article)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:load_topic, topic}, socket) do
    Logger.info("GraphLive.load_topic start topic=#{topic}")

    {graph_data, error} =
      case Map.fetch(@topics, topic) do
        {:ok, {seed_id, _title}} ->
          case Loader.load_subgraph(seed_id) do
            {:ok, data} ->
              {data, nil}

            {:error, reason} ->
              Logger.error("load_subgraph failed for #{inspect(topic)}: #{inspect(reason)}")
              {%{nodes: [], links: []}, reason}
          end

        :error ->
          Logger.warning("Unknown topic #{inspect(topic)}")
          {%{nodes: [], links: []}, :unknown_topic}
      end

    blom_binary = BlomEncoder.encode(graph_data)
    blom_b64 = Base.encode64(blom_binary)

    Logger.info(
      "GraphLive.load_topic done topic=#{topic} nodes=#{length(graph_data.nodes)} bytes=#{byte_size(blom_binary)}"
    )

    socket =
      socket
      |> assign(:current_topic, topic)
      |> assign(:node_count, length(graph_data.nodes))
      |> assign(:loading, false)
      |> push_event("render-graph", %{data: blom_b64})

    socket =
      case error do
        nil -> socket
        :unknown_topic -> put_flash(socket, :error, "Unknown topic #{topic}")
        :not_found -> put_flash(socket, :error, "No seed article found for #{topic}")
        _ -> put_flash(socket, :error, "Graph load failed — check server logs")
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="graph-container">
      <aside class="sidebar">
        <h2 class="brand">Dedalus ✦ Bloom</h2>
        <p class="brand-sub">Wikipedia neighborhoods</p>

        <p class="section-label">Topics</p>
        <%= for topic <- @topics do %>
          <button
            type="button"
            phx-click="load_topic"
            phx-value-topic={topic}
            phx-disable-with="Loading…"
            class={"topic-btn #{if @current_topic == topic, do: "active", else: ""}"}
          >
            <span>{topic |> String.replace("_", " ") |> String.capitalize()}</span>
            <span class="chevron">→</span>
          </button>
        <% end %>

        <%= if @current_topic do %>
          <p class="section-label">Search</p>
          <input
            type="text"
            class="search-field"
            placeholder="Filter nodes by title…"
            phx-keyup="search"
            phx-debounce="200"
            value={@search_query}
          />

          <div class="stats-card">
            <span class="stat-label">Nodes</span>
            <span class="stat-value">{@node_count}</span>
          </div>

          <p class="section-label">PageRank emergence</p>
          <div class="histogram-card">
            <p class="histogram-caption">
              bars: observed visit share · lines: ground-truth PageRank
            </p>
            <canvas
              id="walker-histogram"
              class="walker-histogram"
              phx-update="ignore"
            />
          </div>
        <% end %>

        <%= if @selected_node do %>
          <div class="node-details">
            <h3>{@selected_node.title}</h3>
            <p class="meta">
              <strong>PageRank</strong>
              <span>{format_pagerank(@selected_node.pagerank)}</span>
            </p>
            <p class="meta">
              <strong>Degree</strong>
              <span>{@selected_node.degree || 0}</span>
            </p>
          </div>
        <% end %>
      </aside>

      <div class="graph-canvas-wrapper">
        <canvas
          id="graph-canvas"
          phx-hook="GraphViz"
          phx-update="ignore"
          class="graph-canvas"
        />
        <canvas
          id="walker-overlay"
          class="graph-walker-overlay"
          phx-update="ignore"
        />
        <div class={"graph-overlay #{if @loading, do: "visible", else: ""}"}>
          <div class="spinner">Loading graph</div>
        </div>
      </div>
    </div>
    """
  end

  defp format_pagerank(nil), do: "—"

  defp format_pagerank(pr) when is_number(pr) do
    :io_lib.format("~.4e", [pr * 1.0]) |> IO.iodata_to_binary()
  end
end
