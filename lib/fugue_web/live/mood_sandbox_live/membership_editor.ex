defmodule FugueWeb.MoodSandboxLive.MembershipEditor do
  @moduledoc "Renders the five per-dimension triangular membership editors and the control buttons."

  use FugueWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4">
      <div class="flex items-center justify-between mb-3 flex-wrap gap-3">
        <h2 class="text-lg font-semibold text-gray-100">Membership functions</h2>
        <div class="flex gap-2">
          <button
            type="button"
            phx-click="mf_suggest"
            class="btn btn-xs btn-outline"
          >
            Auto-suggest from data
          </button>
          <button
            type="button"
            phx-click="mf_apply_suggestion"
            disabled={is_nil(@suggestion)}
            class="btn btn-xs btn-primary"
          >
            Apply suggestion
          </button>
          <button
            type="button"
            phx-click="mf_reset"
            class="btn btn-xs btn-ghost"
          >
            Reset to defaults
          </button>
        </div>
      </div>

      <p class="text-xs text-gray-500 mb-4 max-w-3xl">
        Each curve says how much a given value counts as <em>low</em>, <em>medium</em>,
        or <em>high</em>. Drag the dots to reshape. Histogram bars behind the curves
        are the actual distribution of my raw scores for that dimension.
      </p>

      <div
        id="membership-editor-root"
        phx-hook="MembershipEditor"
        phx-update="ignore"
        class="grid grid-cols-1 md:grid-cols-2 gap-4"
      >
      </div>
    </div>
    """
  end
end
