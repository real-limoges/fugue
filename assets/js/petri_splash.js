// @ts-check
import { resolveThemeColors, buildColorTable } from "./lib/theme_colors.js"

/**
 * The part of a petri wrapper the splash loop drives once it is started.
 * The wrappers are vendored, untyped JS imported by relative path, so their
 * types are inferred from the source; this names the shape the loop needs.
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
      const m = await import("../vendor/petri/js/boids.js")
      await m.init()
      m.start(1500, w, h)
      return m
    },
    steps: 1,
  },
  langton: {
    start: async (w, h) => {
      const m = await import("../vendor/petri/js/langton.js")
      await m.init()
      m.start(8, w, h)
      return m
    },
    steps: 500,
  },
  oscillators: {
    start: async (w, h) => {
      const m = await import("../vendor/petri/js/oscillators.js")
      await m.init()
      m.start(w, h)
      return m
    },
    steps: 2,
  },
  sandpile: {
    start: async (w, h) => {
      const m = await import("../vendor/petri/js/sandpile.js")
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

  const canvasW = window.innerWidth
  const canvasH = window.innerHeight
  canvas.width = canvasW
  canvas.height = canvasH

  const ctx = canvas.getContext("2d")
  if (!ctx) return null

  const mod = await sim.start(canvasW, canvasH)
  if (thisGeneration !== generation) return null

  let lut = refreshColors()
  const pixelCount = canvasW * canvasH
  const rgbaBuffer = new Uint8ClampedArray(pixelCount * 4)

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

  let rafId = 0
  let frameCount = 0

  // An arrow, not a function declaration, so the non-null `ctx` narrowing
  // above carries into it.
  const loop = () => {
    mod.step(sim.steps)

    if (++frameCount % 120 === 0) lut = refreshColors()

    const intensity = mod.getPixels()

    for (let i = 0; i < pixelCount; i++) {
      const lutOffset = intensity[i] * 4
      const rgbaOffset = i * 4
      rgbaBuffer[rgbaOffset] = lut[lutOffset]
      rgbaBuffer[rgbaOffset + 1] = lut[lutOffset + 1]
      rgbaBuffer[rgbaOffset + 2] = lut[lutOffset + 2]
      rgbaBuffer[rgbaOffset + 3] = 255
    }

    const imageData = new ImageData(rgbaBuffer, canvasW, canvasH)
    ctx.putImageData(imageData, 0, 0)

    updateReading(performance.now(), intensity)

    rafId = requestAnimationFrame(loop)
  }
  rafId = requestAnimationFrame(loop)

  cleanup = () => cancelAnimationFrame(rafId)
  return cleanup
}
