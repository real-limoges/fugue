defmodule FugueWeb.SandboxLive.QuantumWalk do
  @moduledoc """
  Classical vs quantum random walk, side by side, with a decoherence slider
  that morphs the quantum walk into the classical one.
  """

  use FugueWeb, :live_view

  @defaults %{steps: 80, decoherence: 0.0}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults)}
  end

  def handle_event("update_params", form, socket) do
    new_params = %{
      steps: parse_int(form["steps"], socket.assigns.params.steps),
      decoherence: parse_float(form["decoherence"], socket.assigns.params.decoherence)
    }

    if new_params == socket.assigns.params do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:params, new_params)
       |> push_event("quantum_walk:set_params", new_params)}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:params, @defaults)
     |> push_event("quantum_walk:set_params", @defaults)}
  end

  defp parse_int(raw, fallback) when is_binary(raw) do
    case Integer.parse(raw) do
      {n, _} -> n
      :error -> fallback
    end
  end

  defp parse_int(_, fallback), do: fallback

  defp parse_float(raw, fallback) when is_binary(raw) do
    case Float.parse(raw) do
      {f, _} -> f
      :error -> fallback
    end
  end

  defp parse_float(_, fallback), do: fallback

  defp format_decoherence(d), do: :erlang.float_to_binary(d, decimals: 2)

  def render(assigns) do
    ~H"""
    <div class="quantum-walk-sandbox p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/sandbox"} class="text-gray-500 hover:text-gray-300">
          ← Sandbox
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Classical vs quantum walk</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Both walkers start at the center and take {@params.steps} steps. The gray
          one takes a classical random walk — coin flip, step, coin flip, step —
          and settles into the familiar bell curve. The cyan one takes a quantum
          walk, and does something strange: it refuses to settle in the middle and
          spreads to the edges instead, piling up in two sharp horns at the outer
          limits of where it could possibly be.
        </p>
        <p class="text-sm text-gray-400 mt-3 max-w-3xl leading-relaxed">
          Drag decoherence. At zero, the quantum walker stays weird. Turn it up
          and the weirdness drains out step by step until you're back to the bell.
          The slider is the dial that turns quantum into classical.
        </p>
      </div>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <canvas
          id="sandbox-quantum-walk-canvas"
          phx-hook="QuantumWalk"
          phx-update="ignore"
          class="block w-full"
          style="height: 420px;"
          data-steps={@params.steps}
          data-decoherence={@params.decoherence}
        >
        </canvas>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <button type="button" phx-click="reset" class="btn btn-xs btn-ghost">
          Reset
        </button>
      </div>

      <form phx-change="update_params" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <label class="block bg-base-200 rounded-lg p-3">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold text-gray-300">Decoherence</span>
            <span class="text-xs font-mono text-gray-400">{format_decoherence(@params.decoherence)}</span>
          </div>
          <input
            type="range"
            name="decoherence"
            min="0"
            max="1"
            step="0.01"
            value={@params.decoherence}
            class="range range-xs range-primary"
          />
        </label>

        <label class="block bg-base-200 rounded-lg p-3">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold text-gray-300">Steps</span>
            <span class="text-xs font-mono text-gray-400">{@params.steps}</span>
          </div>
          <input
            type="range"
            name="steps"
            min="10"
            max="160"
            step="2"
            value={@params.steps}
            class="range range-xs range-primary"
          />
        </label>
      </form>
    </div>
    """
  end
end
