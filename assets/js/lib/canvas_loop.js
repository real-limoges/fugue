// @ts-check
// Utilities for canvases driven by a continuous RAF loop: every animation
// on the site (the home splash, the menagerie sims, the /mood attractor,
// the /color hero, the /about bricks) runs through `startRafLoop`. The
// rest is periodic theme-color repolling and the inner pixel-mapping
// loop. Each caller composes these in its own setup rather than handing
// config to a factory, so the hooks stay readable.

const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

/**
 * Runs `step` once per animation frame, but only while `target` is on
 * screen and the tab is visible; it pauses otherwise and picks up again
 * when both are true. `step` gets the frame's timestamp, on the same clock
 * as `performance.now()`.
 *
 * `still` is for decorative motion. When it is given and the visitor's
 * system asks for reduced motion, `still` runs once, to draw a resting
 * frame, and no loop starts. Leave it out for something the visitor is
 * driving (a menagerie sim with sliders), which keeps running either way.
 *
 * `fps` caps how often `step` runs. Without it `step` runs on every frame,
 * so a 120 Hz screen does twice the work of a 60 Hz one and a simulation
 * moves twice as fast there.
 *
 * The returned `stop` is for the hook's destroyed(): it cancels the frame
 * and removes the listeners.
 *
 * @param {(now: number) => void} step
 * @param {{target: Element, still?: () => void, fps?: number}} options
 * @returns {{stop: () => void}}
 */
export function startRafLoop(step, { target, still, fps }) {
  if (still && matchMedia(REDUCED_MOTION).matches) {
    still()
    return { stop: () => {} }
  }

  const due = fps ? createFrameGate(fps) : () => true

  /** @type {number | null} */
  let id = null
  let onScreen = true
  let stopped = false

  const shouldRun = () => !stopped && onScreen && document.visibilityState === "visible"

  const pause = () => {
    if (id !== null) cancelAnimationFrame(id)
    id = null
  }

  /** @param {number} now */
  const tick = (now) => {
    id = null
    if (due(now)) step(now)
    resume()
  }

  const resume = () => {
    if (id === null && shouldRun()) id = requestAnimationFrame(tick)
  }

  const sync = () => (shouldRun() ? resume() : pause())

  const observer = new IntersectionObserver((entries) => {
    onScreen = entries[entries.length - 1].isIntersecting
    sync()
  })
  observer.observe(target)
  document.addEventListener("visibilitychange", sync)
  resume()

  return {
    stop: () => {
      stopped = true
      pause()
      observer.disconnect()
      document.removeEventListener("visibilitychange", sync)
    },
  }
}

// Frame timestamps jitter by a millisecond or two, so a frame this close to
// its deadline counts as on time. Without the slack a 60 Hz screen would
// skip every frame that landed a hair early and run at half speed.
const FRAME_SLACK_MS = 2

/**
 * Says, for each animation frame's timestamp, whether a loop capped at
 * `fps` should run on it. Deadlines are spaced 1000 / fps apart, so the
 * average rate holds even on screens whose refresh rate is not a multiple
 * of `fps` (144 Hz under a 60 cap runs on two frames out of five, then
 * three). After a pause, the first frame runs and the schedule restarts
 * from it instead of catching up.
 *
 * @param {number} fps
 * @returns {(now: number) => boolean}
 */
export function createFrameGate(fps) {
  const interval = 1000 / fps
  /** @type {number | null} */
  let deadline = null

  return (now) => {
    // The first frame, or one a whole interval past its deadline (the loop
    // was paused): run, and start the schedule over from here.
    if (deadline === null || now - deadline >= interval) {
      deadline = now + interval
      return true
    }
    if (now < deadline - FRAME_SLACK_MS) return false
    deadline += interval
    return true
  }
}

// Map an intensity buffer (one byte per pixel) through a 1024-byte color
// table (4 bytes per entry, 256 entries) into a packed RGBA buffer. All
// three buffers must be the same length in pixels.
/**
 * @param {Uint8Array} intensity
 * @param {Uint8Array} colorTable
 * @param {Uint8ClampedArray | Uint8Array} rgba
 * @returns {void}
 */
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
