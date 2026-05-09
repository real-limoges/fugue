// Utilities for hooks whose canvas is driven by a continuous RAF loop --
// today: boids, sandpile. The lifecycle is RAF id management, periodic
// theme-color repolling, and the inner pixel-mapping loop. Each hook
// composes these in its own mount() rather than handing config to a
// factory; they stay readable as Phoenix hooks.
//
// Pattern documented in CONTEXT.md as "themed canvas hook".

// Owns RAF id and cleanup. The caller's `step` is invoked every animation
// frame; the returned `{ stop }` is intended for the hook's destroyed().
export function startRafLoop(step) {
  let id = null
  const tick = () => {
    step()
    id = requestAnimationFrame(tick)
  }
  id = requestAnimationFrame(tick)
  return {
    stop: () => {
      if (id !== null) cancelAnimationFrame(id)
    },
  }
}

// Throttle a side effect to every N frames. Caller invokes the returned
// function inside its RAF step; `onChange` fires when the counter rolls
// over. Used to repoll theme colors without reading getComputedStyle on
// every frame.
export function createThemePoll({ frames, onChange }) {
  let n = 0
  return () => {
    if (++n % frames === 0) onChange()
  }
}

// Map an intensity buffer (one byte per pixel) through a 1024-byte color
// table (4 bytes per entry, 256 entries) into a packed RGBA buffer. All
// three buffers must be the same length in pixels.
export function mapPixels(intensity, colorTable, rgba) {
  const len = intensity.length
  for (let i = 0; i < len; i++) {
    const c = intensity[i] * 4
    const o = i * 4
    rgba[o] = colorTable[c]
    rgba[o + 1] = colorTable[c + 1]
    rgba[o + 2] = colorTable[c + 2]
    rgba[o + 3] = colorTable[c + 3]
  }
}
