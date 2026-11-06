// @ts-check
import * as sandpile from "../../vendor/petri/js/sandpile.js"
import * as d3 from "d3"
import { resolveThemeColors, buildColorTable } from "../lib/theme_colors.js"
import { startRafLoop, createThemePoll, mapPixels } from "../lib/canvas_loop.js"

function axisColor() {
  return (
    getComputedStyle(document.documentElement).getPropertyValue("--color-base-content").trim() ||
    "#666"
  )
}

/** @param {HTMLElement} container */
function setupHistogram(container) {
  const margin = { top: 8, right: 12, bottom: 28, left: 36 }
  const width = container.clientWidth || 320
  const height = 160
  const innerW = width - margin.left - margin.right
  const innerH = height - margin.top - margin.bottom

  const svg = d3.select(container).append("svg").attr("width", width).attr("height", height)

  const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

  const x = d3.scaleLog().domain([1, 1000]).range([0, innerW])
  const y = d3.scaleLog().domain([1, 1000]).range([innerH, 0])

  g.append("g")
    .attr("class", "x-axis")
    .attr("transform", `translate(0,${innerH})`)
    .call(d3.axisBottom(x).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", axisColor())
    .attr("fill", axisColor())

  g.append("g")
    .attr("class", "y-axis")
    .call(d3.axisLeft(y).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", axisColor())
    .attr("fill", axisColor())

  svg
    .append("text")
    .attr("x", margin.left + innerW / 2)
    .attr("y", height - 2)
    .attr("text-anchor", "middle")
    .attr("fill", axisColor())
    .attr("font-size", "10px")
    .text("avalanche size")

  svg
    .append("text")
    .attr("transform", `translate(10,${margin.top + innerH / 2}) rotate(-90)`)
    .attr("text-anchor", "middle")
    .attr("fill", axisColor())
    .attr("font-size", "10px")
    .text("count")

  const dotsGroup = g.append("g")

  return { g, x, y, innerW, innerH, dotsGroup }
}

/** @typedef {{size: number, count: number}} HistPoint */
/** @typedef {ReturnType<typeof setupHistogram>} HistChart */

/**
 * @param {HistChart} chart
 * @param {Map<number, number>} bins avalanche size to count
 */
function updateHistogram(chart, bins) {
  // bins: Map<size, count>; filter to size >= 1
  /** @type {HistPoint[]} */
  const data = []
  for (const [size, count] of bins) {
    if (size >= 1 && count >= 1) data.push({ size, count })
  }
  // Empty after a reset: clear the old dots and leave the axes where they were.
  if (data.length === 0) {
    chart.dotsGroup.selectAll("circle").remove()
    return
  }

  const maxSize = d3.max(data, (d) => d.size) || 1000
  const maxCount = d3.max(data, (d) => d.count) || 1000
  chart.x.domain([1, Math.max(10, maxSize * 1.5)])
  chart.y.domain([1, Math.max(10, maxCount * 1.5)])

  // The annotations supply select's element type argument: the axes are the
  // <g> elements setupHistogram appended, and an axis only renders into a <g>.
  /** @type {d3.Selection<SVGGElement, unknown, null, undefined>} */
  const xAxisG = chart.g.select(".x-axis")
  /** @type {d3.Selection<SVGGElement, unknown, null, undefined>} */
  const yAxisG = chart.g.select(".y-axis")

  xAxisG
    .call(d3.axisBottom(chart.x).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", axisColor())
    .attr("fill", axisColor())
  yAxisG
    .call(d3.axisLeft(chart.y).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", axisColor())
    .attr("fill", axisColor())

  // The annotation supplies selectAll's type arguments (element and datum),
  // which JS cannot write inline; every circle here was bound to a HistPoint.
  /** @type {d3.Selection<SVGCircleElement, HistPoint, SVGGElement, unknown>} */
  const existing = chart.dotsGroup.selectAll("circle")
  const dots = existing.data(data, (d) => d.size)
  dots
    .enter()
    .append("circle")
    .attr("r", 2)
    .attr("fill", axisColor())
    .attr("opacity", 0.7)
    .merge(dots)
    .attr("cx", (d) => chart.x(d.size))
    .attr("cy", (d) => chart.y(d.count))
  dots.exit().remove()
}

/**
 * @typedef {object} State
 * @property {{stop: () => void}} [_loop]
 * @property {() => void} [_onThemeChanged]
 * @property {boolean} [_destroyed] set by destroyed(); mounted() checks it after its awaits
 * @property {number} _width
 * @property {number} _height
 */

/** @type {import("../types").LiveHook<State>} */
export const SandpileCanvas = {
  async mounted() {
    try {
      await new Promise((r) => requestAnimationFrame(r))

      const canvas = this.el
      if (!(canvas instanceof HTMLCanvasElement)) throw new Error("SandpileCanvas needs a <canvas>")
      const rect = canvas.getBoundingClientRect()
      const width = Math.max(1, Math.floor(rect.width) || canvas.clientWidth || 512)
      const height = Math.max(1, Math.floor(rect.height) || canvas.clientHeight || 512)
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext("2d")
      if (!ctx) throw new Error("SandpileCanvas: no 2D context")

      await sandpile.init()
      // Navigated away while the WASM loaded: start nothing destroyed() can't stop.
      if (this._destroyed) return
      sandpile.start(width, height)

      const initialColors = resolveThemeColors()
      let colorTable = buildColorTable(initialColors.base, initialColors.primary)
      const rgba = new Uint8ClampedArray(width * height * 4)

      // Avalanche size tracking
      /** @type {Map<number, number>} */
      const avalancheBins = new Map()
      /** @type {HistChart | null} */
      let histChart = null
      const histContainer = document.getElementById("sandpile-histogram")
      if (histContainer) histChart = setupHistogram(histContainer)

      let dropsPerFrame = 10
      let frame = 0
      let histDirty = false

      const grainCounter = document.getElementById("sandpile-grain-count")

      const repollThemeColors = () => {
        const fresh = resolveThemeColors()
        colorTable = buildColorTable(fresh.base, fresh.primary)
        if (histChart) {
          histChart.g
            .select(".x-axis")
            .selectAll("text, line, path")
            .attr("stroke", axisColor())
            .attr("fill", axisColor())
          histChart.g
            .select(".y-axis")
            .selectAll("text, line, path")
            .attr("stroke", axisColor())
            .attr("fill", axisColor())
          histChart.dotsGroup.selectAll("circle").attr("fill", axisColor())
        }
      }
      const repollTheme = createThemePoll({ frames: 120, onChange: repollThemeColors })
      this._onThemeChanged = repollThemeColors
      window.addEventListener("fugue:theme-changed", this._onThemeChanged)

      this._loop = startRafLoop(() => {
        sandpile.step(dropsPerFrame)

        const avalSize = sandpile.getLastAvalancheSize()
        if (avalSize > 0) {
          avalancheBins.set(avalSize, (avalancheBins.get(avalSize) || 0) + 1)
          histDirty = true
        }

        if (grainCounter) grainCounter.textContent = sandpile.getTotalGrains().toLocaleString()

        repollTheme()

        // Update histogram every 60 frames
        if (histChart && histDirty && ++frame % 60 === 0) {
          updateHistogram(histChart, avalancheBins)
          histDirty = false
        }

        mapPixels(sandpile.getPixels(), colorTable, rgba)
        ctx.putImageData(new ImageData(rgba, width, height), 0, 0)
      })

      this._width = width
      this._height = height

      // Click-to-drop
      canvas.addEventListener("click", (/** @type {MouseEvent} */ e) => {
        const r = canvas.getBoundingClientRect()
        const x = Math.floor((e.clientX - r.left) * (width / r.width))
        const y = Math.floor((e.clientY - r.top) * (height / r.height))
        sandpile.drop(x, y)
      })

      // LiveView events
      this.handleEvent("sandpile:set_mode", (/** @type {{mode: string}} */ { mode }) => {
        sandpile.setMode(mode === "random" ? 1 : 0)
      })

      this.handleEvent("sandpile:set_params", (/** @type {{speed: number}} */ { speed }) => {
        dropsPerFrame = Math.max(1, Math.min(200, speed))
      })

      this.handleEvent(
        "sandpile:reset",
        (/** @type {{mode: string, speed: number}} */ { mode, speed }) => {
          sandpile.start(this._width, this._height)
          sandpile.setMode(mode === "random" ? 1 : 0)
          dropsPerFrame = speed || 10
          avalancheBins.clear()
          if (histChart) updateHistogram(histChart, avalancheBins)
          if (grainCounter) grainCounter.textContent = "0"
        }
      )
    } catch (err) {
      console.error("[SandpileCanvas] mount failed:", err)
    }
  },

  destroyed() {
    this._destroyed = true
    if (this._loop) this._loop.stop()
    if (this._onThemeChanged)
      window.removeEventListener("fugue:theme-changed", this._onThemeChanged)
  },
}
