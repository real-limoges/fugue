import * as d3 from "d3"

const MARGIN = { top: 5, right: 20, bottom: 20, left: 30 }
const WIDTH = 800
const HEIGHT = 50
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom
const parseDate = d3.timeParse("%Y-%m-%d")

export const TemporalBrush = {
  mounted() {
    this.svg = null
    this.dates = []
    this.brush = null

    this.handleEvent("update-brush-timeline", ({ dates }) => {
      this.dates = dates
      this.render()
    })

    this.handleEvent("clear-brush", () => {
      if (this.brush && this.svg) {
        this.svg.select(".brush").call(this.brush.move, null)
      }
    })
  },

  render() {
    if (!this.dates || this.dates.length === 0) return

    this.el.innerHTML = ""

    const allDates = this.dates.map(d => parseDate(d)).filter(Boolean)
    if (allDates.length === 0) return

    const svgEl = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    this.svg = svgEl

    const g = svgEl.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleTime()
      .domain(d3.extent(allDates))
      .range([0, INNER_W])

    // Tick marks for each day
    g.selectAll("line.tick")
      .data(allDates)
      .join("line")
      .attr("class", "tick")
      .attr("x1", d => x(d))
      .attr("x2", d => x(d))
      .attr("y1", 0)
      .attr("y2", INNER_H)
      .attr("stroke", "#555")
      .attr("stroke-width", 1)
      .attr("opacity", 0.4)

    // Axis
    g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(d3.axisBottom(x).ticks(d3.timeMonth.every(3)).tickFormat(d3.timeFormat("%b %Y")))
      .selectAll("text,line,path").attr("stroke", "#666").attr("fill", "#666").attr("font-size", "9px")

    // Brush
    const formatDate = d3.timeFormat("%Y-%m-%d")

    this.brush = d3.brushX()
      .extent([[0, 0], [INNER_W, INNER_H]])
      .on("end", (event) => {
        if (!event.selection) {
          this.pushEvent("brush_changed", { start: null, end: null })
          return
        }
        const [x0, x1] = event.selection.map(x.invert)
        this.pushEvent("brush_changed", {
          start: formatDate(x0),
          end: formatDate(x1)
        })
      })

    g.append("g")
      .attr("class", "brush")
      .call(this.brush)
      .selectAll("rect")
      .attr("height", INNER_H)
      .attr("rx", 2)
  },

  destroyed() {
    this.brush = null
    this.svg = null
  }
}
