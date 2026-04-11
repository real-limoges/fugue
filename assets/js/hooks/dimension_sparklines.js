import * as d3 from "d3"
import { DIM_COLORS } from "./constants"

/** Time-series sparkline for each mood dimension. */
const MARGIN = { top: 4, right: 12, bottom: 28, left: 70 }
const ROW_HEIGHT = 56
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

    const rowInnerH = ROW_HEIGHT - 8 // padding between rows
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

      const g = svgEl.append("g")
        .attr("transform", `translate(${MARGIN.left}, ${yOffset})`)

      const vals = data.map(d => d.values[dim]).filter(v => v != null)
      let [lo, hi] = d3.extent(vals)
      if (lo === hi) { lo -= 0.5; hi += 0.5 }
      // Add a little breathing room
      const pad = (hi - lo) * 0.08
      lo -= pad
      hi += pad

      const y = d3.scaleLinear()
        .domain([lo, hi])
        .range([rowInnerH, 0])

      // Subtle horizontal gridlines
      const ticks = y.ticks(3)
      ticks.forEach(t => {
        g.append("line")
          .attr("x1", 0).attr("x2", INNER_W)
          .attr("y1", y(t)).attr("y2", y(t))
          .attr("stroke", "rgba(255,255,255,0.04)")
      })

      // Area fill
      const area = d3.area()
        .defined(d => d.values[dim] != null)
        .x(d => x(d.date))
        .y0(rowInnerH)
        .y1(d => y(d.values[dim]))
        .curve(d3.curveBasis)

      g.append("path")
        .datum(data)
        .attr("d", area)
        .attr("fill", color)
        .attr("fill-opacity", 0.1)

      // Line
      const line = d3.line()
        .defined(d => d.values[dim] != null)
        .x(d => x(d.date))
        .y(d => y(d.values[dim]))
        .curve(d3.curveBasis)

      g.append("path")
        .datum(data)
        .attr("d", line)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.8)

      // Dimension label
      svgEl.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", yOffset + rowInnerH / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", color)
        .attr("font-size", "11px")
        .attr("font-weight", "600")
        .text(dim)

      // Y-axis range labels (high / low)
      svgEl.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", yOffset + 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "hanging")
        .attr("fill", "#555")
        .attr("font-size", "8px")
        .text(d3.max(vals).toFixed(0))

      svgEl.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", yOffset + rowInnerH - 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "auto")
        .attr("fill", "#555")
        .attr("font-size", "8px")
        .text(d3.min(vals).toFixed(0))

      // Row separator
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
