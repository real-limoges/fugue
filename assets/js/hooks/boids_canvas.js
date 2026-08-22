import * as boids from "../../vendor/petri/js/boids.js"
import { resolveThemeColors, buildColorTable } from "../lib/theme_colors.js"
import { startRafLoop, createThemePoll, mapPixels } from "../lib/canvas_loop.js"

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

      const initialColors = resolveThemeColors()
      let colorTable = buildColorTable(initialColors.base, initialColors.primary)
      const rgba = new Uint8ClampedArray(width * height * 4)

      const repollThemeColors = () => {
        const fresh = resolveThemeColors()
        colorTable = buildColorTable(fresh.base, fresh.primary)
      }
      const repollTheme = createThemePoll({ frames: 120, onChange: repollThemeColors })
      this._onThemeChanged = repollThemeColors
      window.addEventListener("fugue:theme-changed", this._onThemeChanged)

      this._loop = startRafLoop(() => {
        boids.step(1)
        repollTheme()
        mapPixels(boids.getPixels(), colorTable, rgba)
        ctx.putImageData(new ImageData(rgba, width, height), 0, 0)
      })

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
    if (this._loop) this._loop.stop()
    if (this._onThemeChanged)
      window.removeEventListener("fugue:theme-changed", this._onThemeChanged)
  },
}
