defmodule FugueWeb.MoodLive.GapAnalysis do
  @moduledoc "Renders the gap histogram visualization."

  use FugueWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="gap-section bg-base-200 rounded-lg p-4">
      <h2 class="text-lg font-semibold mb-3">Gap Analysis</h2>

      <div
        id="gap-histogram"
        phx-hook="GapHistogram"
        phx-update="ignore"
        style="min-height: 120px;"
      >
      </div>
    </div>
    """
  end
end
