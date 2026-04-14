import * as d3 from "d3"

/**
 * Editable triangular membership functions — one SVG per input dimension.
 * Renders histogram of actual values behind, triangles for low/medium/high,
 * and draggable control points. Commits on drag end via mf_commit event.
 */

const TERM_COLORS = {
  low: "#42c8e6",
  medium: "#e6e042",
  high: "#e44dbc"
}

const WIDTH = 340
const HEIGHT = 150
const MARGIN = { top: 14, right: 10, bottom: 22, left: 10 }
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom

export const MembershipEditor = {
  mounted() {
    this.defs = null
    this.histograms = null
    this.suggestion = null
    this.dragging = false

    this.handleEvent("update-membership-editor", ({ defs, histograms }) => {
      this.defs = structuredClone(defs)
      this.histograms = histograms
      this.suggestion = null
      this.renderAll()
    })

    this.handleEvent("show-suggestion", ({ defs }) => {
      this.suggestion = defs
      this.renderAll()
    })

    this.handleEvent("clear-suggestion", () => {
      this.suggestion = null
      this.renderAll()
    })
  },

  destroyed() {
    this.el.innerHTML = ""
  },

  renderAll() {
    if (!this.defs || !this.defs.inputs) return

    const existing = new Set()
    for (const v of this.defs.inputs) existing.add(v.name)

    for (const child of Array.from(this.el.children)) {
      if (!existing.has(child.dataset.var)) child.remove()
    }

    for (const varDef of this.defs.inputs) {
      let panel = this.el.querySelector(`[data-var="${varDef.name}"]`)
      if (!panel) {
        panel = document.createElement("div")
        panel.dataset.var = varDef.name
        panel.className = "bg-base-300/40 rounded p-2"
        this.el.appendChild(panel)
      }
      this.renderPanel(panel, varDef)
    }
  },

  renderPanel(panel, varDef) {
    const suggestionVar =
      this.suggestion && this.suggestion.inputs
        ? this.suggestion.inputs.find(v => v.name === varDef.name)
        : null

    let svg = d3.select(panel).select("svg")
    if (svg.empty()) {
      panel.innerHTML = `<div class="text-xs font-semibold text-gray-300 mb-1 uppercase tracking-wide">${varDef.name}</div>`
      svg = d3
        .select(panel)
        .append("svg")
        .attr("width", "100%")
        .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
        .style("display", "block")
        .style("overflow", "visible")

      const g = svg.append("g").attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)
      g.append("g").attr("class", "hist-layer")
      g.append("g").attr("class", "suggestion-layer")
      g.append("g").attr("class", "triangle-layer")
      g.append("g").attr("class", "handle-layer")
      g.append("g").attr("class", "axis-layer").attr("transform", `translate(0,${INNER_H})`)
    }

    const [lo, hi] = varDef.bounds
    const x = d3.scaleLinear().domain([lo, hi]).range([0, INNER_W])
    const y = d3.scaleLinear().domain([0, 1]).range([INNER_H, 0])

    const g = svg.select("g")

    const bins = (this.histograms && this.histograms[varDef.name]) || []
    const histLayer = g.select(".hist-layer")
    const bars = histLayer.selectAll("rect").data(bins)
    bars.exit().remove()
    bars
      .enter()
      .append("rect")
      .merge(bars)
      .attr("x", d => x(d.x0))
      .attr("width", d => Math.max(0, x(d.x1) - x(d.x0) - 1))
      .attr("y", d => y(d.n))
      .attr("height", d => INNER_H - y(d.n))
      .attr("fill", "#ffffff")
      .attr("fill-opacity", 0.08)

    const suggestionLayer = g.select(".suggestion-layer")
    if (suggestionVar) {
      const ghostData = suggestionVar.terms.map(t => ({ term: t, varDef: suggestionVar }))
      const ghosts = suggestionLayer.selectAll("path").data(ghostData)
      ghosts.exit().remove()
      ghosts
        .enter()
        .append("path")
        .merge(ghosts)
        .attr("d", d => trianglePath(d.term.params, x, y))
        .attr("fill", "none")
        .attr("stroke", d => TERM_COLORS[d.term.name] || "#ffffff")
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "3,3")
        .attr("stroke-opacity", 0.75)
    } else {
      suggestionLayer.selectAll("path").remove()
    }

    const triangleLayer = g.select(".triangle-layer")
    const triData = varDef.terms.map(t => ({ term: t, varDef }))
    const tris = triangleLayer.selectAll("path").data(triData, d => d.term.name)
    tris.exit().remove()
    tris
      .enter()
      .append("path")
      .merge(tris)
      .attr("d", d => trianglePath(d.term.params, x, y))
      .attr("fill", d => TERM_COLORS[d.term.name] || "#ffffff")
      .attr("fill-opacity", 0.12)
      .attr("stroke", d => TERM_COLORS[d.term.name] || "#ffffff")
      .attr("stroke-width", 1.5)

    const handles = []
    varDef.terms.forEach((term, termIdx) => {
      term.params.forEach((val, pointIdx) => {
        handles.push({
          varName: varDef.name,
          termIdx,
          pointIdx,
          value: val,
          color: TERM_COLORS[term.name] || "#ffffff"
        })
      })
    })

    const handleLayer = g.select(".handle-layer")
    const dots = handleLayer.selectAll("circle").data(handles, d => `${d.termIdx}-${d.pointIdx}`)
    dots.exit().remove()

    const hook = this
    const merged = dots
      .enter()
      .append("circle")
      .attr("r", 4.5)
      .style("cursor", "ew-resize")
      .merge(dots)
      .attr("cx", d => x(d.value))
      .attr("cy", d => (d.pointIdx === 1 ? y(1) : y(0)))
      .attr("fill", d => d.color)
      .attr("stroke", "#0a0a1a")
      .attr("stroke-width", 1)

    merged.call(
      d3
        .drag()
        .on("start", function () {
          hook.dragging = true
          d3.select(this).attr("r", 6.5)
        })
        .on("drag", function (event, d) {
          const rawVal = x.invert(event.x)
          const bounds = hook.pointBounds(varDef.name, d.termIdx, d.pointIdx)
          const clamped = Math.max(bounds[0], Math.min(bounds[1], rawVal))
          hook.applyLocalEdit(varDef.name, d.termIdx, d.pointIdx, clamped)
          hook.renderPanel(panel, hook.currentVarDef(varDef.name))
        })
        .on("end", function () {
          hook.dragging = false
          d3.select(this).attr("r", 4.5)
          hook.pushEvent("mf_commit", { inputs: hook.defs.inputs })
        })
    )

    const axis = g
      .select(".axis-layer")
      .call(d3.axisBottom(x).ticks(4).tickSize(2))

    axis.selectAll("path").attr("stroke", "#555")
    axis.selectAll("line").attr("stroke", "#555")
    axis.selectAll("text").attr("fill", "#888").attr("font-size", 9)
  },

  currentVarDef(varName) {
    return this.defs.inputs.find(v => v.name === varName)
  },

  pointBounds(varName, termIdx, pointIdx) {
    const varDef = this.currentVarDef(varName)
    const [lo, hi] = varDef.bounds
    const [a, peak, c] = varDef.terms[termIdx].params
    if (pointIdx === 0) return [lo, peak]
    if (pointIdx === 1) return [a, c]
    return [peak, hi]
  },

  applyLocalEdit(varName, termIdx, pointIdx, newValue) {
    const varDef = this.currentVarDef(varName)
    const params = [...varDef.terms[termIdx].params]
    params[pointIdx] = newValue
    varDef.terms[termIdx] = { ...varDef.terms[termIdx], params }
  }
}

function trianglePath(params, x, y) {
  const [a, peak, c] = params
  return `M${x(a)},${y(0)} L${x(peak)},${y(1)} L${x(c)},${y(0)} Z`
}
