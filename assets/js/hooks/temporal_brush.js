// @ts-check
import * as d3 from "d3"

const MARGIN = { top: 5, right: 20, bottom: 20, left: 30 }
const WIDTH = 800
const HEIGHT = 50
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom
const parseDate = d3.timeParse("%Y-%m-%d")

/**
 * @typedef {object} State
 * @property {string[]} dates ISO-8601 days, pushed by the server
 * @property {import("d3").BrushBehavior<unknown> | null} brush
 * @property {import("d3").Selection<SVGGElement, unknown, null, undefined> | null} brushG
 *   the group the brush is drawn into, kept so `clear-brush` can reset it
 */

/**
 * @typedef {object} Methods
 * @property {() => void} render
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const TemporalBrush = {
  mounted() {
    this.dates = []
    this.brush = null
    this.brushG = null

    this.handleEvent("update-brush-timeline", (/** @type {{dates: string[]}} */ { dates }) => {
      this.dates = dates
      this.render()
    })

    this.handleEvent("clear-brush", () => {
      if (this.brush && this.brushG) {
        this.brushG.call(this.brush.move, null)
      }
    })
  },

  render() {
    if (this.dates.length === 0) return

    this.el.innerHTML = ""

    const allDates = this.dates.map((d) => parseDate(d)).filter((d) => d !== null)
    const [first, last] = d3.extent(allDates)
    if (!first || !last) return

    const svgEl = d3
      .select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    const g = svgEl.append("g").attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleTime().domain([first, last]).range([0, INNER_W])

    // Tick marks for each day
    g.selectAll("line.tick")
      .data(allDates)
      .join("line")
      .attr("class", "tick")
      .attr("x1", (d) => x(d))
      .attr("x2", (d) => x(d))
      .attr("y1", 0)
      .attr("y2", INNER_H)
      .attr("stroke", "#555")
      .attr("stroke-width", 1)
      .attr("opacity", 0.4)

    // Axis. d3's types let an axis tick be a number; a time scale's are
    // always Dates.
    const formatMonth = d3.timeFormat("%b %Y")
    const axis = d3
      .axisBottom(x)
      .ticks(d3.timeMonth.every(3))
      .tickFormat((d) => formatMonth(/** @type {Date} */ (d)))

    g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(axis)
      .selectAll("text,line,path")
      .attr("stroke", "#666")
      .attr("fill", "#666")
      .attr("font-size", "9px")

    // Brush
    const formatDate = d3.timeFormat("%Y-%m-%d")

    this.brush = d3
      .brushX()
      .extent([
        [0, 0],
        [INNER_W, INNER_H],
      ])
      .on("end", (/** @type {import("d3").D3BrushEvent<unknown>} */ event) => {
        if (!event.selection) {
          this.pushEvent("brush_changed", { start: null, end: null })
          return
        }
        // brushX selections are one-dimensional: [x0, x1] in pixels.
        const [px0, px1] = /** @type {[number, number]} */ (event.selection)
        this.pushEvent("brush_changed", {
          start: formatDate(x.invert(px0)),
          end: formatDate(x.invert(px1)),
        })
      })

    this.brushG = g.append("g").attr("class", "brush")
    this.brushG.call(this.brush).selectAll("rect").attr("height", INNER_H).attr("rx", 2)
  },

  destroyed() {
    this.brush = null
    this.brushG = null
  },
}
