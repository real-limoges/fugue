import * as d3 from "d3"
import { DIM_COLORS } from "./constants"

/** Small-multiples sparklines — 90-day rolling average per dimension, showing long-term drift. */
const MARGIN = { top: 6, right: 15, bottom: 24, left: 72 }
const WIDTH = 800
const ROW_H = 44
const GAP = 8
const parseDate = d3.timeParse("%Y-%m-%d")

export const DimensionDrift = {
  mounted() {
    this.handleEvent("update-drift", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { dimensions } = this.data
    if (!dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""

    const totalH = MARGIN.top + MARGIN.bottom + dimensions.length * (ROW_H + GAP) - GAP
    const innerW = WIDTH - MARGIN.left - MARGIN.right

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${totalH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    // Shared x scale
    const allDates = dimensions[0].series.map(d => parseDate(d.date))
    const x = d3.scaleTime()
      .domain(d3.extent(allDates))
      .range([0, innerW])

    dimensions.forEach((dim, i) => {
      const rowY = MARGIN.top + i * (ROW_H + GAP)
      const color = DIM_COLORS[dim.dimension] || "#888"

      const g = svg.append("g")
        .attr("transform", `translate(${MARGIN.left}, ${rowY})`)

      // Per-row y scale
      const values = dim.series.map(d => d.value)
      const yMin = d3.min(values)
      const yMax = d3.max(values)
      const yPad = (yMax - yMin) * 0.15 || 0.5
      const y = d3.scaleLinear()
        .domain([yMin - yPad, yMax + yPad])
        .range([ROW_H, 0])

      // Subtle background
      g.append("rect")
        .attr("width", innerW)
        .attr("height", ROW_H)
        .attr("fill", "rgba(255,255,255,0.015)")
        .attr("rx", 3)

      // Overall mean reference line
      const mean = d3.mean(values)
      g.append("line")
        .attr("x1", 0)
        .attr("x2", innerW)
        .attr("y1", y(mean))
        .attr("y2", y(mean))
        .attr("stroke", "rgba(255,255,255,0.08)")
        .attr("stroke-width", 0.5)
        .attr("stroke-dasharray", "3,3")

      // Rolling average line
      const line = d3.line()
        .x(d => x(parseDate(d.date)))
        .y(d => y(d.value))
        .curve(d3.curveBasis)

      g.append("path")
        .datum(dim.series)
        .attr("d", line)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.8)

      // Dimension label
      svg.append("text")
        .attr("x", MARGIN.left - 8)
        .attr("y", rowY + ROW_H / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "central")
        .attr("fill", color)
        .attr("font-size", "10px")
        .attr("font-weight", "600")
        .text(dim.dimension)

      // Scale hints: first and last value
      const first = values[0]
      const last = values[values.length - 1]

      g.append("text")
        .attr("x", -2)
        .attr("y", y(first))
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "central")
        .attr("fill", "#444")
        .attr("font-size", "8px")
        .text(first.toFixed(1))

      g.append("text")
        .attr("x", innerW + 4)
        .attr("y", y(last))
        .attr("dominant-baseline", "central")
        .attr("fill", "#555")
        .attr("font-size", "8px")
        .text(last.toFixed(1))
    })

    // Shared x axis at bottom
    const axisY = MARGIN.top + dimensions.length * (ROW_H + GAP) - GAP
    const xAxisG = svg.append("g")
      .attr("transform", `translate(${MARGIN.left}, ${axisY})`)
      .call(d3.axisBottom(x).ticks(d3.timeYear.every(1)).tickFormat(d3.timeFormat("%Y")).tickSize(3))
    xAxisG.select(".domain").attr("stroke", "#444")
    xAxisG.selectAll(".tick line").attr("stroke", "#444")
    xAxisG.selectAll(".tick text").attr("fill", "#666").attr("font-size", "10px")
  }
}
