import * as d3 from "d3"
import { DIM_COLORS } from "./constants"

/** Per-dimension z-score sparklines — each row is centered on its own
 *  baseline (mean) and scaled to its own standard deviation, so variation
 *  fills the row instead of being squished into the tight [3,7]-ish band
 *  that raw 0–10 scores usually live in. */
const MARGIN = { top: 4, right: 12, bottom: 28, left: 78 }
const ROW_HEIGHT = 64
const SPARK_W = 700
const INNER_W = SPARK_W - MARGIN.left - MARGIN.right

export const DimensionSparklines = {
  mounted() {
    this.data = { entries: [], dimensions: [] }

    this.handleEvent("update-sparklines", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { entries, dimensions } = this.data
    if (!entries || entries.length === 0 || !dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""

    const parseDate = d3.timeParse("%Y-%m-%d")
    const data = entries.map(e => ({
      date: parseDate(e.date),
      values: e.dimensions || {}
    })).filter(d => d.date)

    if (data.length === 0) return

    const rowInnerH = ROW_HEIGHT - 10
    const totalH = MARGIN.top + dimensions.length * ROW_HEIGHT + MARGIN.bottom
    const svgEl = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${SPARK_W} ${totalH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    const x = d3.scaleTime()
      .domain(d3.extent(data, d => d.date))
      .range([0, INNER_W])

    dimensions.forEach((dim, i) => {
      const yOffset = MARGIN.top + i * ROW_HEIGHT
      const color = DIM_COLORS[dim] || "#888"

      const vals = data.map(d => d.values[dim]).filter(v => v != null)
      if (vals.length === 0) return

      const mean = d3.mean(vals)
      const sd = d3.deviation(vals) || 1

      // Pre-compute z-scores aligned to `data` indices (null where missing).
      const zVals = data.map(d => {
        const v = d.values[dim]
        return v == null ? null : (v - mean) / sd
      })

      // Symmetric y-domain so zero (mean) is always the midpoint of the row.
      // Clamp to at least ±1σ so rows with tiny variance still have a sensible scale.
      const maxAbsZ = Math.max(
        1,
        d3.max(zVals, z => z == null ? 0 : Math.abs(z)) || 1
      )

      const y = d3.scaleLinear()
        .domain([-maxAbsZ, maxAbsZ])
        .range([rowInnerH, 0])

      const g = svgEl.append("g")
        .attr("transform", `translate(${MARGIN.left}, ${yOffset})`)

      // Zero baseline (the dimension's own mean).
      g.append("line")
        .attr("x1", 0).attr("x2", INNER_W)
        .attr("y1", y(0)).attr("y2", y(0))
        .attr("stroke", "rgba(255,255,255,0.2)")
        .attr("stroke-dasharray", "2 3")

      // Area from baseline to line — fills above or below naturally.
      const area = d3.area()
        .defined((_d, j) => zVals[j] != null)
        .x(d => x(d.date))
        .y0(y(0))
        .y1((_d, j) => y(zVals[j]))
        .curve(d3.curveMonotoneX)

      g.append("path")
        .datum(data)
        .attr("d", area)
        .attr("fill", color)
        .attr("fill-opacity", 0.28)

      // Line on top.
      const line = d3.line()
        .defined((_d, j) => zVals[j] != null)
        .x(d => x(d.date))
        .y((_d, j) => y(zVals[j]))
        .curve(d3.curveMonotoneX)

      g.append("path")
        .datum(data)
        .attr("d", line)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.95)

      // Dimension label + baseline mean underneath it.
      svgEl.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", yOffset + rowInnerH / 2 - 4)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", color)
        .attr("font-size", "11px")
        .attr("font-weight", "600")
        .text(dim)

      svgEl.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", yOffset + rowInnerH / 2 + 8)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", "#666")
        .attr("font-size", "8px")
        .text(`μ ${mean.toFixed(1)}`)

      // +/- σ range labels top and bottom of the row.
      svgEl.append("text")
        .attr("x", MARGIN.left - 4)
        .attr("y", yOffset + 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "hanging")
        .attr("fill", "#555")
        .attr("font-size", "8px")
        .text(`+${maxAbsZ.toFixed(1)}σ`)

      svgEl.append("text")
        .attr("x", MARGIN.left - 4)
        .attr("y", yOffset + rowInnerH - 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "auto")
        .attr("fill", "#555")
        .attr("font-size", "8px")
        .text(`−${maxAbsZ.toFixed(1)}σ`)

      // Row separator.
      if (i < dimensions.length - 1) {
        svgEl.append("line")
          .attr("x1", MARGIN.left)
          .attr("x2", SPARK_W - MARGIN.right)
          .attr("y1", yOffset + ROW_HEIGHT - 2)
          .attr("y2", yOffset + ROW_HEIGHT - 2)
          .attr("stroke", "rgba(255,255,255,0.05)")
      }
    })

    // Shared x-axis at bottom
    const axisY = MARGIN.top + dimensions.length * ROW_HEIGHT + 4
    const axisG = svgEl.append("g")
      .attr("transform", `translate(${MARGIN.left}, ${axisY})`)

    const xAxis = d3.axisBottom(x)
      .ticks(d3.timeYear.every(1))
      .tickFormat(d3.timeFormat("%Y"))
      .tickSize(4)

    axisG.call(xAxis)
    axisG.select(".domain").attr("stroke", "#444")
    axisG.selectAll(".tick line").attr("stroke", "#444")
    axisG.selectAll(".tick text")
      .attr("fill", "#777")
      .attr("font-size", "10px")
  }
}
