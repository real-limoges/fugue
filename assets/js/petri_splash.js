// @ts-check
import { resolveThemeColors, buildColorTable } from "./lib/theme_colors.js"
import { startRafLoop, mapPixels } from "./lib/canvas_loop.js"

// Under reduced motion the splash shows one still frame instead of a loop.
// The sim first runs this many frames' worth of steps so the still is the
// settled pattern (a flock, an ant highway) rather than the random seed.
const SETTLE_FRAMES = 240

// Sim steps per second, whatever the screen's refresh rate. Uncapped, a
// 120 Hz screen ran twice the steps of a 60 Hz one: twice the CPU, and a
// flock moving twice as fast.
const STEPS_PER_SECOND = 60

/**
 * The part of a petri wrapper the splash loop drives once it is started;
 * every wrapper in `sims` has this shape.
 * @typedef {object} PetriSim
 * @property {(n: number) => void} step
 * @property {() => Uint8Array} getPixels
 */

/**
 * `start` loads the wrapper, initializes its WASM, and seeds a sim sized to
 * the canvas; `steps` is how many sim steps run per animation frame.
 * @typedef {object} SplashSim
 * @property {(w: number, h: number) => Promise<PetriSim>} start
 * @property {number} steps
 */

/** @type {Record<string, SplashSim>} */
const sims = {
  boids: {
    start: async (w, h) => {
      const m = await import("petri/boids.js")
      await m.init()
      m.start(1500, w, h)
      return m
    },
    steps: 1,
  },
  langton: {
    start: async (w, h) => {
      const m = await import("petri/langton.js")
      await m.init()
      m.start(8, w, h)
      return m
    },
    steps: 500,
  },
  oscillators: {
    start: async (w, h) => {
      const m = await import("petri/oscillators.js")
      await m.init()
      m.start(w, h)
      return m
    },
    steps: 2,
  },
  sandpile: {
    start: async (w, h) => {
      const m = await import("petri/sandpile.js")
      await m.init()
      m.start(w, h)
      return m
    },
    steps: 10,
  },
}

// Memoize the color table across splash swaps so theme switches rebuild
// the LUT exactly once per change rather than every animation tick.
/** @type {string | null} */
let cachedColors = null
/** @type {Uint8Array | null} */
let cachedRGBA = null

/** @returns {Uint8Array} the color table for the current theme */
function refreshColors() {
  const colors = resolveThemeColors()
  const key = colors.base.join(",") + "|" + colors.primary.join(",")
  if (cachedColors !== key || cachedRGBA === null) {
    cachedColors = key
    cachedRGBA = buildColorTable(colors.base, colors.primary)
  }
  return cachedRGBA
}

/** @type {(() => void) | null} */
let cleanup = null

// Bumped on every initSplash call. Starting a sim awaits a WASM load, so a
// second call can land while the first is still waiting; the first then sees
// a newer generation when it wakes and gives up instead of starting a loop
// nothing would ever cancel.
let generation = 0

/**
 * @param {string} canvasId
 * @param {string} simName
 * @param {string} [readingId] element that shows a live activity readout
 * @returns {Promise<(() => void) | null>} stops the splash
 */
export async function initSplash(canvasId, simName, readingId) {
  const thisGeneration = ++generation
  if (cleanup) {
    cleanup()
    cleanup = null
  }

  const sim = sims[simName]
  if (!sim) return null

  const canvas = document.getElementById(canvasId)
  if (!(canvas instanceof HTMLCanvasElement)) return null

  // Sized to the box the canvas sits in, not the window: the box is shorter
  // than the window, so a window-sized sim spent its time on rows nobody saw.
  const canvasW = Math.max(1, canvas.clientWidth || window.innerWidth)
  const canvasH = Math.max(1, canvas.clientHeight || window.innerHeight)
  canvas.width = canvasW
  canvas.height = canvasH

  const ctx = canvas.getContext("2d")
  if (!ctx) return null

  const mod = await sim.start(canvasW, canvasH)
  if (thisGeneration !== generation) return null

  let lut = refreshColors()
  const pixelCount = canvasW * canvasH
  const image = ctx.createImageData(canvasW, canvasH)

  const reading = readingId ? document.getElementById(readingId) : null
  const startTime = performance.now()
  const sampleStride = 64
  const sampleCount = Math.max(1, Math.floor(pixelCount / sampleStride))
  let lastReadingUpdate = 0
  /** @type {number | null} */
  let activityEMA = null

  /**
   * @param {number} now
   * @param {Uint8Array} intensity
   */
  function updateReading(now, intensity) {
    if (!reading) return
    if (now - lastReadingUpdate < 250) return
    lastReadingUpdate = now

    let sum = 0
    for (let i = 0; i < pixelCount; i += sampleStride) sum += intensity[i]
    const mean = sum / sampleCount / 255
    activityEMA = activityEMA === null ? mean : activityEMA * 0.7 + mean * 0.3

    const elapsed = Math.floor((now - startTime) / 1000)
    const mm = String(Math.floor(elapsed / 60)).padStart(2, "0")
    const ss = String(elapsed % 60).padStart(2, "0")
    reading.textContent = `${simName} · ${activityEMA.toFixed(2)} · t+${mm}:${ss}`
  }

  let frameCount = 0

  // Arrows, not function declarations, so the non-null `ctx` narrowing
  // above carries into them.
  const draw = () => {
    const intensity = mod.getPixels()
    mapPixels(intensity, lut, image.data)
    ctx.putImageData(image, 0, 0)
    updateReading(performance.now(), intensity)
  }

  const loop = startRafLoop(
    () => {
      mod.step(sim.steps)
      if (++frameCount % 120 === 0) lut = refreshColors()
      draw()
    },
    {
      target: canvas,
      fps: STEPS_PER_SECOND,
      still: () => {
        mod.step(sim.steps * SETTLE_FRAMES)
        draw()
      },
    }
  )

  cleanup = loop.stop
  return cleanup
}
