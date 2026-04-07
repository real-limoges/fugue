import * as d3 from "d3"

const MARGIN = { top: 10, right: 10, bottom: 30, left: 35 }
const WIDTH = 400
const HEIGHT = 150
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom

export const GapHistogram = {
  mounted() {
    this.svg = null

    this.handleEvent("update-gaps", (data) => {
      this.renderHistogram(data.lengthDistribution || {})
    })
  },

  renderHistogram(distribution) {
    this.el.innerHTML = ""

    const entries = Object.entries(distribution)
      .map(([len, count]) => ({ length: parseInt(len), count }))
      .sort((a, b) => a.length - b.length)

    if (entries.length === 0) {
      this.el.innerHTML = '<p style="color:#666;text-align:center;padding:20px">No gap data</p>'
      return
    }

    const svgEl = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    this.svg = svgEl

    const g = svgEl.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleBand()
      .domain(entries.map(d => d.length))
      .range([0, INNER_W])
      .padding(0.2)

    const y = d3.scaleLinear()
      .domain([0, d3.max(entries, d => d.count)])
      .nice()
      .range([INNER_H, 0])

    // Axes
    g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(d3.axisBottom(x).tickValues(
        entries.length > 15
          ? entries.filter((_, i) => i % Math.ceil(entries.length / 10) === 0).map(d => d.length)
          : entries.map(d => d.length)
      ))
      .selectAll("text,line,path").attr("stroke", "#666").attr("fill", "#666")

    g.append("g")
      .call(d3.axisLeft(y).ticks(4))
      .selectAll("text,line,path").attr("stroke", "#666").attr("fill", "#666")

    // Axis label
    g.append("text")
      .attr("x", INNER_W / 2)
      .attr("y", INNER_H + 25)
      .attr("text-anchor", "middle")
      .attr("fill", "#666")
      .attr("font-size", "10px")
      .text("Gap length (days)")

    // Bars
    g.selectAll("rect.bar")
      .data(entries)
      .join("rect")
      .attr("class", "bar")
      .attr("x", d => x(d.length))
      .attr("y", d => y(d.count))
      .attr("width", x.bandwidth())
      .attr("height", d => INNER_H - y(d.count))
      .attr("fill", "#3498db")
      .attr("opacity", 0.7)
      .attr("rx", 1)
      .style("cursor", "pointer")
      .on("mouseenter", function() {
        d3.select(this).attr("opacity", 1)
      })
      .on("mouseleave", function() {
        d3.select(this).attr("opacity", 0.7)
      })
  },

  destroyed() {}
}
