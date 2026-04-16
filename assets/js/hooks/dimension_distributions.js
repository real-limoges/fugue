import * as d3 from "d3"
import { DIM_COLORS } from "./constants"

/**
 * Per-cluster ridge distributions: one row per dimension, each row shows
 * overlapping translucent density curves — one per cluster — so you can see
 * how a dimension's shape shifts between states. A thin dashed outline behind
 * them is the overall (unfiltered) distribution as a reference.
 *
 * Each row has its own data-driven x scale and its own tiny axis underneath,
 * because the five dimensions don't all live on the same native range.
 */

const ROW_H = 92
const LABEL_W = 90
const MARGIN = { top: 10, right: 28, bottom: 10, left: 12 }
const SAMPLE_POINTS = 80
const BANDWIDTH_FRAC = 0.07

// Each mood dimension is rated on a fixed integer scale: sleep is 0–15
// (hours), outlook and speed are 0–10, sensitivity and anxiety are 0–5.
// Pinning the x-domain per dimension keeps the axes honest (no KDE padding
// leaking into negatives) and preserves the real differences in rating
// range across rows.
const DIM_DOMAINS = {
  sleep: [0, 15],
  outlook: [0, 10],
  speed: [0, 10],
  anxiety: [0, 5],
  sensitivity: [0, 5]
}
const DIM_TICKS = {
  sleep: [0, 3, 6, 9, 12, 15],
  outlook: [0, 2, 4, 6, 8, 10],
  speed: [0, 2, 4, 6, 8, 10],
  anxiety: [0, 1, 2, 3, 4, 5],
  sensitivity: [0, 1, 2, 3, 4, 5]
}
const FALLBACK_DOMAIN = [0, 10]
const FALLBACK_TICKS = [0, 2, 4, 6, 8, 10]

function gaussianKde(values, bandwidth) {
  const h = bandwidth
  const norm = 1 / (Math.sqrt(2 * Math.PI) * h)
  return (x) => {
    let sum = 0
    for (let i = 0; i < values.length; i++) {
      const z = (x - values[i]) / h
      sum += Math.exp(-0.5 * z * z)
    }
    return (sum / values.length) * norm
  }
}

function densityCurve(values, domain, bandwidth) {
  if (values.length === 0) return []
  const kde = gaussianKde(values, bandwidth)
  const step = (domain[1] - domain[0]) / SAMPLE_POINTS
  const out = []
  for (let i = 0; i <= SAMPLE_POINTS; i++) {
    const x = domain[0] + i * step
    out.push([x, kde(x)])
  }
  return out
}

export const DimensionDistributions = {
  mounted() {
    this.data = { points: [], dimensions: [], clusters: [] }
    this._cachedCurves = null

    this.handleEvent("update-distributions", (data) => {
      this.data = data
      this._cachedCurves = null
      this.render()
    })

    this.resize = () => this.render()
    window.addEventListener("resize", this.resize)
  },

  destroyed() {
    window.removeEventListener("resize", this.resize)
  },

  computeCurves() {
    if (this._cachedCurves) return this._cachedCurves

    const { points, dimensions, clusters } = this.data
    this._cachedCurves = dimensions.map(dim => {
      const allValues = points
        .map(p => (p.dimensions || {})[dim])
        .filter(v => v != null)

      if (allValues.length === 0) return { dim, empty: true }

      const domain = DIM_DOMAINS[dim] || FALLBACK_DOMAIN
      const bandwidth = Math.max((domain[1] - domain[0]) * BANDWIDTH_FRAC, 0.05)

      const clusterCurves = clusters.map(c => {
        const vals = points
          .filter(p => p.cluster === c.id)
          .map(p => (p.dimensions || {})[dim])
          .filter(v => v != null)
        return { cluster: c, curve: densityCurve(vals, domain, bandwidth), n: vals.length }
      })
      const overallCurve = densityCurve(allValues, domain, bandwidth)

      const maxDensity = d3.max([
        d3.max(overallCurve, d => d[1]) || 0,
        ...clusterCurves.map(cc => d3.max(cc.curve, d => d[1]) || 0)
      ]) || 1

      return { dim, domain, clusterCurves, overallCurve, maxDensity, empty: false }
    })

    return this._cachedCurves
  },

  render() {
    const { dimensions } = this.data
    if (!dimensions || dimensions.length === 0) return

    const curves = this.computeCurves()
    if (!curves || curves.every(c => c.empty)) return

    this.el.innerHTML = ""

    const containerW = this.el.clientWidth || 640
    const chartW = containerW - LABEL_W - MARGIN.left - MARGIN.right
    const totalH = MARGIN.top + dimensions.length * ROW_H + MARGIN.bottom

    const svg = d3.select(this.el)
      .append("svg")
      .attr("width", containerW)
      .attr("height", totalH)

    curves.forEach((row, rowIdx) => {
      if (row.empty) return

      const { dim, domain, clusterCurves, overallCurve, maxDensity } = row
      const rowTop = MARGIN.top + rowIdx * ROW_H
      const plotTop = rowTop + 10
      const plotBottom = rowTop + ROW_H - 28
      const axisY = plotBottom + 2

      const x = d3.scaleLinear().domain(domain).range([0, chartW])
      const y = d3.scaleLinear().domain([0, maxDensity]).range([plotBottom, plotTop])

      svg.append("text")
        .attr("x", LABEL_W - 10)
        .attr("y", (plotTop + plotBottom) / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", DIM_COLORS[dim] || "#aaa")
        .attr("font-size", "12px")
        .attr("font-weight", "600")
        .text(dim)

      const g = svg.append("g").attr("transform", `translate(${LABEL_W + MARGIN.left},0)`)

      g.append("line")
        .attr("x1", 0).attr("x2", chartW)
        .attr("y1", plotBottom).attr("y2", plotBottom)
        .attr("stroke", "rgba(255,255,255,0.1)")
        .attr("stroke-width", 1)

      const areaGen = d3.area()
        .x(d => x(d[0]))
        .y0(plotBottom)
        .y1(d => y(d[1]))
        .curve(d3.curveBasis)

      const lineGen = d3.line()
        .x(d => x(d[0]))
        .y(d => y(d[1]))
        .curve(d3.curveBasis)

      g.append("path")
        .attr("d", lineGen(overallCurve))
        .attr("fill", "none")
        .attr("stroke", "rgba(255,255,255,0.28)")
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "2 3")

      clusterCurves
        .slice()
        .sort((a, b) => b.n - a.n)
        .forEach(({ cluster, curve }) => {
          if (curve.length === 0) return
          g.append("path")
            .attr("d", areaGen(curve))
            .attr("fill", cluster.color)
            .attr("fill-opacity", 0.22)
            .attr("stroke", cluster.color)
            .attr("stroke-width", 1.5)
            .attr("stroke-opacity", 0.9)
        })

      const axisG = svg.append("g")
        .attr("transform", `translate(${LABEL_W + MARGIN.left}, ${axisY})`)

      const tickVals = DIM_TICKS[dim] || FALLBACK_TICKS

      tickVals.forEach(t => {
        axisG.append("line")
          .attr("x1", x(t)).attr("x2", x(t))
          .attr("y1", 0).attr("y2", 4)
          .attr("stroke", "rgba(255,255,255,0.25)")
          .attr("stroke-width", 1)

        axisG.append("text")
          .attr("x", x(t))
          .attr("y", 15)
          .attr("text-anchor", t === tickVals[0] ? "start" : t === tickVals[tickVals.length - 1] ? "end" : "middle")
          .attr("fill", "#6b7280")
          .attr("font-size", "10px")
          .text(formatTick(t))
      })
    })
  }
}

function formatTick(v) {
  if (Number.isInteger(v)) return String(v)
  return v.toFixed(1)
}
