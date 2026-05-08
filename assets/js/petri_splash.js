import { resolveThemeColors, buildColorTable } from "./lib/theme_colors.js"

const sims = {
  boids: {
    module: () => import("../vendor/petri/js/boids.js"),
    setup: async (m, w, h) => {
      await m.init()
      m.start(1500, w, h)
    },
    loop: (m) => m.step(1),
  },
  langton: {
    module: () => import("../vendor/petri/js/langton.js"),
    setup: async (m, w, h) => {
      await m.init()
      m.start(8, w, h)
    },
    loop: (m) => m.step(500),
  },
  oscillators: {
    module: () => import("../vendor/petri/js/oscillators.js"),
    setup: async (m, w, h) => {
      await m.init()
      m.start(w, h)
    },
    loop: (m) => m.step(2),
  },
  sandpile: {
    module: () => import("../vendor/petri/js/sandpile.js"),
    setup: async (m, w, h) => {
      await m.init()
      m.start(w, h)
    },
    loop: (m) => m.step(10),
  },
}

// Memoize the color table across splash swaps so theme switches rebuild
// the LUT exactly once per change rather than every animation tick.
let cachedColors = null
let cachedRGBA = null

function refreshColors() {
  const colors = resolveThemeColors()
  const key = colors.base.join(",") + "|" + colors.primary.join(",")
  if (cachedColors !== key) {
    cachedColors = key
    cachedRGBA = buildColorTable(colors.base, colors.primary)
  }
}

let cleanup = null

export async function initSplash(canvasId, simName, readingId) {
  if (cleanup) {
    cleanup()
    cleanup = null
  }

  const sim = sims[simName]
  if (!sim) return null

  const canvas = document.getElementById(canvasId)
  if (!canvas) return null

  const canvasW = window.innerWidth
  const canvasH = window.innerHeight
  canvas.width = canvasW
  canvas.height = canvasH

  const ctx = canvas.getContext("2d")

  const mod = await sim.module()
  await sim.setup(mod, canvasW, canvasH)

  refreshColors()
  const pixelCount = canvasW * canvasH
  const rgbaBuffer = new Uint8ClampedArray(pixelCount * 4)

  const reading = readingId ? document.getElementById(readingId) : null
  const startTime = performance.now()
  const sampleStride = 64
  const sampleCount = Math.max(1, Math.floor(pixelCount / sampleStride))
  let lastReadingUpdate = 0
  let activityEMA = null

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

  let rafId
  let frameCount = 0

  function loop() {
    sim.loop(mod)

    if (++frameCount % 120 === 0) refreshColors()

    const intensity = mod.getPixels()
    const lut = cachedRGBA

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

export const simNames = Object.keys(sims)
