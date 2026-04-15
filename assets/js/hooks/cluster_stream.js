import * as d3 from "d3"

/** Stacked area chart of cluster membership proportions over time. */
const MARGIN = { top: 10, right: 15, bottom: 24, left: 30 }
const WIDTH = 800
const HEIGHT = 200
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom

export const ClusterStream = {
  mounted() {
    this.data = { series: [], clusterColors: {}, clusterIds: [], clusterNames: {} }
    this.focusDate = null

    this.handleEvent("update-stream", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })

    this.handleEvent("day-focus", ({ day }) => {
      this.focusDate = day?.date || null
      this.applyFocus()
    })
  },

  render() {
    const { series, clusterColors, clusterIds, clusterNames } = this.data
    if (!series || series.length === 0) return

    this.el.innerHTML = ""

    const parseDate = d3.timeParse("%Y-%m-%d")

    const data = series.map(d => ({
      date: parseDate(d.date),
      ...d.memberships
    }))

    if (data.length === 0) return

    const svgEl = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    this.svg = svgEl

    const g = svgEl.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    this.streamG = g

    const x = d3.scaleTime()
      .domain(d3.extent(data, d => d.date))
      .range([0, INNER_W])

    this.x = x

    const y = d3.scaleLinear()
      .domain([0, 1])
      .range([INNER_H, 0])

    const stack = d3.stack()
      .keys(clusterIds)
      .value((d, key) => d[key] || 0)
      .offset(d3.stackOffsetNone)

    const stacked = stack(data)

    const area = d3.area()
      .x(d => x(d.data.date))
      .y0(d => y(d[0]))
      .y1(d => y(d[1]))
      .curve(d3.curveBasis)

    g.selectAll("path.stream-layer")
      .data(stacked)
      .join("path")
      .attr("class", "stream-layer")
      .attr("data-cluster", d => d.key)
      .attr("d", area)
      .attr("fill", d => clusterColors[d.key] || "#666")
      .attr("fill-opacity", 0.65)
      .attr("stroke", d => clusterColors[d.key] || "#666")
      .attr("stroke-width", 0.5)
      .attr("stroke-opacity", 0.3)

    // X axis
    const xAxisG = g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(d3.axisBottom(x).ticks(d3.timeYear.every(1)).tickFormat(d3.timeFormat("%Y")).tickSize(3))
    xAxisG.select(".domain").attr("stroke", "#444")
    xAxisG.selectAll(".tick line").attr("stroke", "#444")
    xAxisG.selectAll(".tick text").attr("fill", "#666").attr("font-size", "10px")

    // Y axis
    const yAxisG = g.append("g")
      .call(d3.axisLeft(y).ticks(2).tickFormat(d3.format(".0%")).tickSize(3))
    yAxisG.select(".domain").attr("stroke", "#444")
    yAxisG.selectAll(".tick line").attr("stroke", "#444")
    yAxisG.selectAll(".tick text").attr("fill", "#666").attr("font-size", "9px")

    // HTML legend below the SVG — wraps naturally
    const hook = this
    const legend = d3.select(this.el)
      .append("div")
      .attr("class", "stream-legend")
      .style("display", "flex")
      .style("flex-wrap", "wrap")
      .style("gap", "6px 12px")
      .style("justify-content", "center")
      .style("margin-top", "6px")

    clusterIds.forEach(id => {
      const name = (clusterNames || {})[id] || id
      const color = clusterColors[id] || "#888"

      const item = legend.append("span")
        .attr("class", "stream-legend-item")
        .attr("data-cluster", id)
        .style("display", "inline-flex")
        .style("align-items", "center")
        .style("gap", "4px")
        .style("cursor", "pointer")
        .style("font-size", "11px")
        .style("font-weight", "500")
        .style("color", color)
        .on("click", () => { hook.pushEvent("cluster_selected", { cluster: id }) })

      item.append("span")
        .style("display", "inline-block")
        .style("width", "8px")
        .style("height", "8px")
        .style("border-radius", "50%")
        .style("background", color)

      item.append("span").text(name)
    })

    this.applyFocus()
  },

  applyFocus() {
    if (!this.streamG || !this.x) return

    this.streamG.selectAll(".tether-line").remove()

    if (!this.focusDate) return

    const parsed = d3.timeParse("%Y-%m-%d")(this.focusDate)
    if (!parsed) return

    const xPos = this.x(parsed)

    this.streamG.append("line")
      .attr("class", "tether-line")
      .attr("x1", xPos).attr("x2", xPos)
      .attr("y1", 0).attr("y2", INNER_H)
      .attr("stroke", "#fff")
      .attr("stroke-width", 1.5)
      .attr("stroke-opacity", 0)
      .attr("pointer-events", "none")
      .transition().duration(220)
      .attr("stroke-opacity", 0.9)
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll("path.stream-layer")
      .attr("fill-opacity", function() {
        if (!cluster) return 0.65
        return d3.select(this).attr("data-cluster") === cluster ? 0.8 : 0.08
      })
      .attr("stroke-opacity", function() {
        if (!cluster) return 0.3
        return d3.select(this).attr("data-cluster") === cluster ? 0.6 : 0.05
      })

    d3.select(this.el).selectAll(".stream-legend-item")
      .style("opacity", function() {
        if (!cluster) return 1
        return d3.select(this).attr("data-cluster") === cluster ? 1 : 0.25
      })
  }
}
