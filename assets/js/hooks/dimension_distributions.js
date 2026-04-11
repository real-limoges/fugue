import * as d3 from "d3"
import { DIM_COLORS } from "./constants"

/** Histograms with IQR box and median/mean markers per dimension. */
const ROW_H = 44
const LABEL_W = 70
const MARGIN = { top: 5, right: 15, bottom: 5, left: 0 }
const BAR_H = 14

export const DimensionDistributions = {
  mounted() {
    this.data = { entries: [], dimensions: [] }

    this.handleEvent("update-distributions", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { entries, dimensions } = this.data
    if (!entries || entries.length === 0 || !dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""

    // Extract values per dimension
    const dimData = {}
    dimensions.forEach(dim => {
      dimData[dim] = entries
        .map(e => (e.dimensions || {})[dim])
        .filter(v => v != null)
    })

    const totalH = MARGIN.top + dimensions.length * ROW_H + MARGIN.bottom
    const containerW = this.el.clientWidth || 320
    const chartW = containerW - LABEL_W - MARGIN.left - MARGIN.right

    const svg = d3.select(this.el)
      .append("svg")
      .attr("width", containerW)
      .attr("height", totalH)

    dimensions.forEach((dim, i) => {
      const vals = dimData[dim]
      if (vals.length === 0) return

      const color = DIM_COLORS[dim] || "#888"
      const y = MARGIN.top + i * ROW_H

      // Label
      svg.append("text")
        .attr("x", LABEL_W - 8)
        .attr("y", y + ROW_H / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", "#999")
        .attr("font-size", "11px")
        .text(dim)

      const g = svg.append("g")
        .attr("transform", `translate(${LABEL_W}, ${y + (ROW_H - BAR_H) / 2})`)

      // Determine domain from data (integers typically 1-5 or 0-10)
      const min = d3.min(vals)
      const max = d3.max(vals)

      const x = d3.scaleLinear()
        .domain([min, max])
        .range([0, chartW])

      // Build histogram bins
      const histogram = d3.bin()
        .domain([min, max + 0.001])
        .thresholds(d3.range(min, max + 1, 1))

      const bins = histogram(vals)
      const maxCount = d3.max(bins, b => b.length) || 1

      // Track bg
      g.append("rect")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", chartW)
        .attr("height", BAR_H)
        .attr("rx", 3)
        .attr("fill", "rgba(255,255,255,0.03)")

      // Bins as rounded rects
      bins.forEach(bin => {
        if (bin.length === 0) return
        const bx = x(bin.x0)
        const bw = Math.max(x(bin.x1) - x(bin.x0) - 1, 2)
        const intensity = bin.length / maxCount

        g.append("rect")
          .attr("x", bx)
          .attr("y", 0)
          .attr("width", bw)
          .attr("height", BAR_H)
          .attr("rx", 2)
          .attr("fill", color)
          .attr("fill-opacity", 0.15 + 0.7 * intensity)
      })

      // Quartile markers
      const sorted = [...vals].sort((a, b) => a - b)
      const q1 = d3.quantile(sorted, 0.25)
      const median = d3.quantile(sorted, 0.5)
      const q3 = d3.quantile(sorted, 0.75)

      // IQR box
      g.append("rect")
        .attr("x", x(q1))
        .attr("y", 1)
        .attr("width", Math.max(x(q3) - x(q1), 2))
        .attr("height", BAR_H - 2)
        .attr("rx", 2)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1)
        .attr("stroke-opacity", 0.6)

      // Median line
      g.append("line")
        .attr("x1", x(median))
        .attr("x2", x(median))
        .attr("y1", 0)
        .attr("y2", BAR_H)
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.9)

      // Mean dot
      const mean = d3.mean(vals)
      g.append("circle")
        .attr("cx", x(mean))
        .attr("cy", BAR_H / 2)
        .attr("r", 2.5)
        .attr("fill", color)
        .attr("fill-opacity", 0.9)

      // Stats text
      svg.append("text")
        .attr("x", LABEL_W + chartW + 4)
        .attr("y", y + ROW_H / 2)
        .attr("dominant-baseline", "middle")
        .attr("fill", "#666")
        .attr("font-size", "9px")
        .text(`μ${mean.toFixed(1)}`)
    })
  }
}
