// Utilities for hooks that draw a static figure parameterized by named
// values, recomputing on phx events and redrawing on resize -- today:
// quantum_walk, quantum_stats. No RAF loop.
//
// Pattern documented in CONTEXT.md as "param figure hook".

// Match a canvas's backing-store size to its CSS box at devicePixelRatio.
// Returns the css size so callers can use it for layout math; they should
// also call `ctx.setTransform(dpr, 0, 0, dpr, 0, 0)` so coordinates stay
// in CSS pixels.
export function setupDprCanvas(canvas) {
  const dpr = window.devicePixelRatio || 1
  const cssWidth = canvas.clientWidth
  const cssHeight = canvas.clientHeight
  if (canvas.width !== cssWidth * dpr || canvas.height !== cssHeight * dpr) {
    canvas.width = cssWidth * dpr
    canvas.height = cssHeight * dpr
  }
  return { dpr, cssWidth, cssHeight }
}

// Re-run `render` whenever `el` resizes. Returns `{ stop }` for the
// hook's destroyed().
export function attachResizeRedraw(el, render) {
  const observer = new ResizeObserver(() => render())
  observer.observe(el)
  return {
    stop: () => observer.disconnect(),
  }
}
