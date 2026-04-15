import * as boids from "../../vendor/petri/js/boids.js"

function resolveThemeColors(canvas) {
  const style = getComputedStyle(document.documentElement)
  const baseProp = style.getPropertyValue("--color-base-100").trim()
  const primaryProp = style.getPropertyValue("--color-primary").trim()

  const probe = document.createElement("canvas")
  probe.width = 1; probe.height = 1
  const pctx = probe.getContext("2d")
  const resolve = (oklchStr, fallback) => {
    if (!oklchStr) return fallback
    pctx.clearRect(0, 0, 1, 1)
    pctx.fillStyle = oklchStr
    pctx.fillRect(0, 0, 1, 1)
    const [r, g, b] = pctx.getImageData(0, 0, 1, 1).data
    return [r, g, b]
  }

  return {
    base: resolve(baseProp, [28, 19, 37]),
    primary: resolve(primaryProp, [200, 50, 180]),
  }
}

function buildColorTable(base, primary) {
  const table = new Uint8Array(256 * 4)
  for (let i = 0; i < 256; i++) {
    const t = i / 255
    const t2 = t * t
    const offset = i * 4
    table[offset]     = base[0] + Math.round((primary[0] - base[0]) * t2)
    table[offset + 1] = base[1] + Math.round((primary[1] - base[1]) * t2)
    table[offset + 2] = base[2] + Math.round((primary[2] - base[2]) * t2)
    table[offset + 3] = 255
  }
  return table
}

function readParamsFromDataset(el) {
  const out = {}
  for (const key of Object.keys(boids.DEFAULTS)) {
    const attr = el.dataset[key] ?? el.dataset[toCamel(key)]
    if (attr !== undefined) out[key] = key === "count" ? parseInt(attr, 10) : parseFloat(attr)
  }
  return out
}

function toCamel(snake) {
  return snake.replace(/_([a-z])/g, (_, c) => c.toUpperCase())
}

export const BoidsCanvas = {
  async mounted() {
    try {
      await new Promise((r) => requestAnimationFrame(r))

      const canvas = this.el
      const rect = canvas.getBoundingClientRect()
      const width = Math.max(1, Math.floor(rect.width) || canvas.clientWidth || 640)
      const height = Math.max(1, Math.floor(rect.height) || canvas.clientHeight || 400)
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext("2d")

      const initial = { ...boids.DEFAULTS, ...readParamsFromDataset(canvas) }

      await boids.init()
      boids.start(initial.count, width, height)
      boids.setParams(initial)

      const initialColors = resolveThemeColors(canvas)
      let colorTable = buildColorTable(initialColors.base, initialColors.primary)
      const pixelCount = width * height
      const rgba = new Uint8ClampedArray(pixelCount * 4)

      let rafId = null
      let frameCount = 0
      const loop = () => {
        boids.step(1)
        if (++frameCount % 120 === 0) {
          const fresh = resolveThemeColors(canvas)
          colorTable = buildColorTable(fresh.base, fresh.primary)
        }
        const intensity = boids.getPixels()
        for (let i = 0; i < pixelCount; i++) {
          const c = intensity[i] * 4
          const o = i * 4
          rgba[o]     = colorTable[c]
          rgba[o + 1] = colorTable[c + 1]
          rgba[o + 2] = colorTable[c + 2]
          rgba[o + 3] = colorTable[c + 3]
        }
        ctx.putImageData(new ImageData(rgba, width, height), 0, 0)
        rafId = requestAnimationFrame(loop)
      }
      loop()

      this._stopLoop = () => { if (rafId !== null) cancelAnimationFrame(rafId) }
      this._width = width
      this._height = height

      this.handleEvent("boids:set_params", (params) => {
        boids.setParams(params)
      })

      this.handleEvent("boids:reset", (params) => {
        const merged = { ...boids.DEFAULTS, ...(params || {}) }
        boids.start(merged.count, this._width, this._height)
        boids.setParams(merged)
      })
    } catch (err) {
      console.error("[BoidsCanvas] mount failed:", err)
    }
  },

  destroyed() {
    if (this._stopLoop) this._stopLoop()
  },
}
