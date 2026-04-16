import * as d3 from "d3"

/** Timeline bar showing contiguous runs of each dominant cluster. */
const MARGIN = { top: 6, right: 15, bottom: 20, left: 30 }
const WIDTH = 800
const HEIGHT = 50
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const BAR_H = 18
const parseDate = d3.timeParse("%Y-%m-%d")

export const TransitionTimeline = {
  mounted() {
    this.data = null

    this.handleEvent("update-mood-transitions", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { segments, transitions, clusterColors } = this.data
    if (!segments || segments.length === 0) return

    this.el.innerHTML = ""

    const allDates = segments.flatMap(s => [parseDate(s.start), parseDate(s.end_date)])
    const extent = d3.extent(allDates)

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    this.svg = svg

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleTime()
      .domain(extent)
      .range([0, INNER_W])

    // Colored segments
    const hook = this
    segments.forEach(seg => {
      const x0 = x(parseDate(seg.start))
      const x1 = x(parseDate(seg.end_date))
      const w = Math.max(x1 - x0, 1)
      const color = clusterColors[seg.cluster] || "#666"

      g.append("rect")
        .attr("class", "tl-segment")
        .attr("data-cluster", seg.cluster)
        .attr("x", x0)
        .attr("y", 0)
        .attr("width", w)
        .attr("height", BAR_H)
        .attr("fill", color)
        .attr("fill-opacity", 0.55)
        .style("cursor", "pointer")
        .on("click", () => {
          hook.pushEvent("cluster_selected", { cluster: seg.cluster })
        })
    })

    // Transition markers
    transitions.forEach(t => {
      const tx = x(parseDate(t.date))

      g.append("line")
        .attr("class", "tl-marker")
        .attr("x1", tx).attr("x2", tx)
        .attr("y1", -2).attr("y2", BAR_H + 2)
        .attr("stroke", "#fff")
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.7)

      g.append("circle")
        .attr("class", "tl-marker")
        .attr("cx", tx)
        .attr("cy", BAR_H / 2)
        .attr("r", 3)
        .attr("fill", "#fff")
        .attr("fill-opacity", 0.9)
    })

    // X axis
    const xAxisG = g.append("g")
      .attr("transform", `translate(0,${BAR_H + 4})`)
      .call(d3.axisBottom(x).ticks(d3.timeYear.every(1)).tickFormat(d3.timeFormat("%Y")).tickSize(3))
    xAxisG.select(".domain").attr("stroke", "#444")
    xAxisG.selectAll(".tick line").attr("stroke", "#444")
    xAxisG.selectAll(".tick text").attr("fill", "#666").attr("font-size", "9px")
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll(".tl-segment")
      .attr("fill-opacity", function () {
        if (!cluster) return 0.55
        return d3.select(this).attr("data-cluster") === cluster ? 0.8 : 0.1
      })
  }
}
