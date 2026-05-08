import * as sandpile from "../../vendor/petri/js/sandpile.js"
import * as d3 from "d3"
import { resolveThemeColors, buildColorTable } from "../lib/theme_colors.js"

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
    .attr("stroke", "#666")
    .attr("fill", "#666")

  g.append("g")
    .attr("class", "y-axis")
    .call(d3.axisLeft(y).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", "#666")
    .attr("fill", "#666")

  svg
    .append("text")
    .attr("x", margin.left + innerW / 2)
    .attr("y", height - 2)
    .attr("text-anchor", "middle")
    .attr("fill", "#666")
    .attr("font-size", "10px")
    .text("avalanche size")

  svg
    .append("text")
    .attr("transform", `translate(10,${margin.top + innerH / 2}) rotate(-90)`)
    .attr("text-anchor", "middle")
    .attr("fill", "#666")
    .attr("font-size", "10px")
    .text("count")

  const dotsGroup = g.append("g")

  return { g, x, y, innerW, innerH, dotsGroup }
}

function updateHistogram(chart, bins) {
  // bins: Map<size, count> — filter to size >= 1
  const data = []
  for (const [size, count] of bins) {
    if (size >= 1 && count >= 1) data.push({ size, count })
  }
  if (data.length === 0) return

  const maxSize = d3.max(data, (d) => d.size) || 1000
  const maxCount = d3.max(data, (d) => d.count) || 1000
  chart.x.domain([1, Math.max(10, maxSize * 1.5)])
  chart.y.domain([1, Math.max(10, maxCount * 1.5)])

  chart.g
    .select(".x-axis")
    .call(d3.axisBottom(chart.x).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", "#666")
    .attr("fill", "#666")
  chart.g
    .select(".y-axis")
    .call(d3.axisLeft(chart.y).ticks(4, "~s"))
    .selectAll("text, line, path")
    .attr("stroke", "#666")
    .attr("fill", "#666")

  const dots = chart.dotsGroup.selectAll("circle").data(data, (d) => d.size)
  dots
    .enter()
    .append("circle")
    .attr("r", 2)
    .attr("fill", "#888")
    .attr("opacity", 0.7)
    .merge(dots)
    .attr("cx", (d) => chart.x(d.size))
    .attr("cy", (d) => chart.y(d.count))
  dots.exit().remove()
}

export const SandpileCanvas = {
  async mounted() {
    try {
      await new Promise((r) => requestAnimationFrame(r))

      const canvas = this.el
      const rect = canvas.getBoundingClientRect()
      const width = Math.max(1, Math.floor(rect.width) || canvas.clientWidth || 512)
      const height = Math.max(1, Math.floor(rect.height) || canvas.clientHeight || 512)
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext("2d")

      await sandpile.init()
      sandpile.start(width, height)

      const initialColors = resolveThemeColors()
      let colorTable = buildColorTable(initialColors.base, initialColors.primary)
      const pixelCount = width * height
      const rgba = new Uint8ClampedArray(pixelCount * 4)

      // Avalanche size tracking
      const avalancheBins = new Map()
      let histChart = null
      const histContainer = document.getElementById("sandpile-histogram")
      if (histContainer) histChart = setupHistogram(histContainer)

      let dropsPerFrame = 10
      let rafId = null
      let frameCount = 0
      let totalGrains = 0
      let histDirty = false

      const grainCounter = document.getElementById("sandpile-grain-count")

      const loop = () => {
        sandpile.step(dropsPerFrame)

        const avalSize = sandpile.getLastAvalancheSize()
        if (avalSize > 0) {
          avalancheBins.set(avalSize, (avalancheBins.get(avalSize) || 0) + 1)
          histDirty = true
        }

        totalGrains = sandpile.getTotalGrains()
        if (grainCounter) grainCounter.textContent = totalGrains.toLocaleString()

        if (++frameCount % 120 === 0) {
          const fresh = resolveThemeColors()
          colorTable = buildColorTable(fresh.base, fresh.primary)
        }

        // Update histogram every 60 frames
        if (histChart && histDirty && frameCount % 60 === 0) {
          updateHistogram(histChart, avalancheBins)
          histDirty = false
        }

        const intensity = sandpile.getPixels()
        for (let i = 0; i < pixelCount; i++) {
          const c = intensity[i] * 4
          const o = i * 4
          rgba[o] = colorTable[c]
          rgba[o + 1] = colorTable[c + 1]
          rgba[o + 2] = colorTable[c + 2]
          rgba[o + 3] = colorTable[c + 3]
        }
        ctx.putImageData(new ImageData(rgba, width, height), 0, 0)
        rafId = requestAnimationFrame(loop)
      }
      loop()

      this._stopLoop = () => {
        if (rafId !== null) cancelAnimationFrame(rafId)
      }
      this._width = width
      this._height = height

      // Click-to-drop
      canvas.addEventListener("click", (e) => {
        const r = canvas.getBoundingClientRect()
        const x = Math.floor((e.clientX - r.left) * (width / r.width))
        const y = Math.floor((e.clientY - r.top) * (height / r.height))
        sandpile.drop(x, y)
      })

      // LiveView events
      this.handleEvent("sandpile:set_mode", ({ mode }) => {
        sandpile.setMode(mode === "random" ? 1 : 0)
      })

      this.handleEvent("sandpile:set_params", ({ speed }) => {
        dropsPerFrame = Math.max(1, Math.min(200, speed))
      })

      this.handleEvent("sandpile:reset", ({ mode, speed }) => {
        sandpile.start(this._width, this._height)
        sandpile.setMode(mode === "random" ? 1 : 0)
        dropsPerFrame = speed || 10
        totalGrains = 0
        avalancheBins.clear()
        if (histChart) updateHistogram(histChart, avalancheBins)
        if (grainCounter) grainCounter.textContent = "0"
      })
    } catch (err) {
      console.error("[SandpileCanvas] mount failed:", err)
    }
  },

  destroyed() {
    if (this._stopLoop) this._stopLoop()
  },
}
