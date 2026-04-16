import * as d3 from "d3"

/** Histogram of max-membership values — shows how often the model struggles to assign a day. */
const MARGIN = { top: 14, right: 15, bottom: 28, left: 36 }
const WIDTH = 800
const HEIGHT = 140
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom

export const AmbiguityHistogram = {
  mounted() {
    this.handleEvent("update-ambiguity", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { bins, threshold } = this.data
    if (!bins || bins.length === 0) return

    this.el.innerHTML = ""

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleLinear()
      .domain([bins[0].x0, bins[bins.length - 1].x1])
      .range([0, INNER_W])

    const y = d3.scaleLinear()
      .domain([0, d3.max(bins, d => d.count)])
      .nice()
      .range([INNER_H, 0])

    // Ambiguous zone background
    g.append("rect")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", x(threshold))
      .attr("height", INNER_H)
      .attr("fill", "rgba(230,165,66,0.06)")

    // Bars
    g.selectAll("rect.bar")
      .data(bins)
      .join("rect")
      .attr("class", "bar")
      .attr("x", d => x(d.x0))
      .attr("width", d => Math.max(0, x(d.x1) - x(d.x0) - 1))
      .attr("y", d => y(d.count))
      .attr("height", d => INNER_H - y(d.count))
      .attr("fill", d => d.x1 <= threshold ? "#e6a542" : "rgba(255,255,255,0.35)")
      .attr("fill-opacity", 0.7)

    // Threshold line
    g.append("line")
      .attr("x1", x(threshold))
      .attr("x2", x(threshold))
      .attr("y1", 0)
      .attr("y2", INNER_H)
      .attr("stroke", "#e6a542")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "4,3")
      .attr("stroke-opacity", 0.8)

    // Zone labels
    g.append("text")
      .attr("x", x(threshold) - 4)
      .attr("y", 6)
      .attr("text-anchor", "end")
      .attr("fill", "#e6a542")
      .attr("font-size", "9px")
      .attr("font-weight", "600")
      .text("in-between")

    g.append("text")
      .attr("x", x(threshold) + 4)
      .attr("y", 6)
      .attr("text-anchor", "start")
      .attr("fill", "#888")
      .attr("font-size", "9px")
      .attr("font-weight", "600")
      .text("decisive")

    // X axis
    const xAxis = g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(d3.axisBottom(x).ticks(6).tickFormat(d3.format(".0%")).tickSize(3))
    xAxis.select(".domain").attr("stroke", "#444")
    xAxis.selectAll(".tick line").attr("stroke", "#444")
    xAxis.selectAll(".tick text").attr("fill", "#666").attr("font-size", "9px")

    // X axis label
    g.append("text")
      .attr("x", INNER_W / 2)
      .attr("y", INNER_H + 24)
      .attr("text-anchor", "middle")
      .attr("fill", "#555")
      .attr("font-size", "9px")
      .text("strongest cluster membership")

    // Y axis
    const yAxis = g.append("g")
      .call(d3.axisLeft(y).ticks(3).tickSize(3))
    yAxis.select(".domain").attr("stroke", "#444")
    yAxis.selectAll(".tick line").attr("stroke", "#444")
    yAxis.selectAll(".tick text").attr("fill", "#666").attr("font-size", "9px")
  }
}
