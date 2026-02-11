defmodule FugueWeb.GraphLive do
  use FugueWeb, :live_view
  alias Fugue.Graph.Loader

  @topics ~w(rust_programming functional_programming)

  def mount(_params, _session, socket) do
    {:ok,
    socket
    |> assign(:topics, @topics)
    |> assign(:current_topic, nil)
    |> assign(:search_query, "")
    |> assign(:node_count, 0)}
  end

  def handle_event("load_topic", %{"topic" => topic}, socket) do
    {:ok, graph_data} = Loader.load_topic(topic)

    {:noreply,
    socket
    |> assign(:current_topic, topic)
    |> assign(:node_count, length(graph_data.nodes))
    |> push_event("render_graph", graph_data)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    topic = socket.assigns.current_topic

    if topic do
      {:ok, subgraph} = Loader.search_subgraph(topic, query)

      {:noreply,
      socket
      |> assign(:search_query, query)
      |> push_event("highlight-nodes", %{node_ids: subgraph.matching_ids})}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="graph-container">
      <div class="sidebar">
        <h2>Dedalus Bloom</h2>

        <div class="topic-selector">
          <h3>Topics</h3>
          <%= for topic <- @topics do %>
            <button
              phx-click="load_topic"
              phx-value-topic={topic}
              class={if @current_topic == topic, do: "active", else: ""}
            >
              <%= topic |> String.replace("_", " ") |> String.capitalize() %>
            </button>
          <% end %>
        </div>

        <%= if @current_topic do %>
          <div class="search-box">
            <input
              type="text"
              placeholder="Search nodes..."
              phx-keyup="search"
              phx-debounce="300"
              value={@search_query}
            />
          </div>

          <div class="stats">
            <p><strong>Nodes:</strong> <%= @node_count %></p>
          </div>
        <% end %>

        <%= if @selected_node do %>
          <div class="node-details">
            <h3><%= @selected_node.title %></h3>
            <p><strong>Categories:</strong></p>
            <ul>
              <%= for cat <- @selected_node.categories do %>
                <li><%= cat %></li>
              <% end %>
            </ul>
            <p class="summary"><%= @selected_node.summary %></p>
          </div>
        <% end %>
      </div>

      <div
        id="graph-canvas"
        phx-hook="GraphViz"
        class="graph-canvas"
      />
    </div>
    """
  end
end