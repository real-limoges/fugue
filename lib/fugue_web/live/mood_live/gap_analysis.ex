defmodule FugueWeb.MoodLive.GapAnalysis do
  @moduledoc "Renders the breath-timeline visualization of silences."

  use FugueWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4">
      <div class="flex items-baseline justify-between mb-1">
        <h3 class="text-sm font-semibold text-gray-200">Breath timeline</h3>
        <span class="text-[10px] uppercase tracking-widest text-gray-500">
          width = duration · height = certainty · color = imputed state
        </span>
      </div>
      <p class="text-xs text-gray-500 mb-3 leading-snug">
        Each shape is a stretch I went quiet. Taller means the model was more sure what state I was in while the page was dark.
      </p>

      <div
        id="gap-breath-timeline"
        phx-hook="GapBreathTimeline"
        phx-update="ignore"
        style="min-height: 170px;"
      >
      </div>
    </div>
    """
  end
end
