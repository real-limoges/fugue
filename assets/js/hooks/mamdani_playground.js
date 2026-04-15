import * as d3 from "d3"

const WIDTH = 820

const FAN_COLORS = {
  off: "#9ca3af",
  low: "#60a5fa",
  medium: "#f59e0b",
  high: "#ec4899"
}

const INPUT_TERM_COLORS = ["#60a5fa", "#f59e0b", "#ec4899"]

function triangular(x, [a, b, c]) {
  if (x <= a || x >= c) return 0
  if (x === b) return 1
  if (x < b) return b === a ? 1 : (x - a) / (b - a)
  return c === b ? 1 : (c - x) / (c - b)
}

function sampleMf(term, bounds, steps = 160) {
  const [lo, hi] = bounds
  const out = []
  for (let i = 0; i <= steps; i++) {
    const x = lo + (i / steps) * (hi - lo)
    out.push([x, triangular(x, term.params)])
  }
  return out
}

function clipTriangle(term, bounds, strength, steps = 160) {
  const s = Math.max(0, Math.min(1, strength))
  return sampleMf(term, bounds, steps).map(([x, y]) => [x, Math.min(y, s)])
}

export const MamdaniPlayground = {
  mounted() {
    this.data = null

    this.handleEvent("update-mamdani", (data) => {
      this.data = data
      this.render()
    })

    this.pushEvent("sandbox:mamdani_ready", {})
  },

  render() {
    if (!this.data) {
      this.el.innerHTML =
        `<div class="py-12 text-center text-xs italic text-gray-500">awaiting inference…</div>`
      return
    }

    const { mfs, rules, inputs, input_degrees, output_curves, crisp } = this.data

    this.el.innerHTML = ""

    const container = d3.select(this.el)
      .append("div")
      .style("display", "flex")
      .style("flex-direction", "column")
      .style("gap", "16px")

    const inputRow = container.append("div")
      .style("display", "grid")
      .style("grid-template-columns", "1fr 1fr")
      .style("gap", "12px")

    const inputVars = mfs.inputs || []
    inputVars.forEach(varDef => {
      this.renderInputPanel(
        inputRow,
        varDef,
        inputs[varDef.name],
        input_degrees[varDef.name] || {}
      )
    })

    this.renderRulesPanel(container, rules || [])

    const outputVar = (mfs.outputs || [])[0]
    if (outputVar) {
      const aggCurve = (output_curves || {})[outputVar.name] || []
      const crispValue = (crisp || {})[outputVar.name]
      this.renderOutputPanel(container, outputVar, aggCurve, crispValue, rules || [])
    }
  },

  renderInputPanel(parent, varDef, crispValue, degrees) {
    const panel = parent.append("div")
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    const header = panel.append("div")
      .attr("class", "flex items-baseline justify-between mb-1")

    header.append("span")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500")
      .text(`${varDef.name.replace(/_/g, " ")} fuzzification`)

    header.append("span")
      .attr("class", "font-mono text-lg font-semibold tabular-nums text-gray-100")
      .text(typeof crispValue === "number" ? d3.format(".1f")(crispValue) : "—")

    const panelW = 400
    const panelH = 176
    const margin = { top: 26, right: 18, bottom: 24, left: 42 }
    const innerW = panelW - margin.left - margin.right
    const innerH = panelH - margin.top - margin.bottom

    const svg = panel.append("svg")
      .attr("viewBox", `0 0 ${panelW} ${panelH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleLinear().domain(varDef.bounds).range([0, innerW])
    const y = d3.scaleLinear().domain([0, 1]).range([innerH, 0])

    g.append("line")
      .attr("x1", 0).attr("x2", innerW)
      .attr("y1", innerH).attr("y2", innerH)
      .attr("stroke", "#374151")

    const line = d3.line().x(d => x(d[0])).y(d => y(d[1]))
    const area = d3.area()
      .x(d => x(d[0]))
      .y0(y(0))
      .y1(d => y(d[1]))

    varDef.terms.forEach((term, i) => {
      const color = INPUT_TERM_COLORS[i % INPUT_TERM_COLORS.length]
      const samples = sampleMf(term, varDef.bounds)

      g.append("path")
        .attr("d", area(samples))
        .attr("fill", color)
        .attr("fill-opacity", 0.12)

      g.append("path")
        .attr("d", line(samples))
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.85)

      const peakPx = x(term.params[1])
      const nearLeft = peakPx < 24
      const nearRight = peakPx > innerW - 24
      g.append("text")
        .attr("x", nearLeft ? 0 : nearRight ? innerW : peakPx)
        .attr("y", -10)
        .attr("fill", color)
        .attr("font-size", 10)
        .attr("font-weight", "600")
        .attr("text-anchor", nearLeft ? "start" : nearRight ? "end" : "middle")
        .text(term.name)
    })

    if (typeof crispValue === "number") {
      g.append("line")
        .attr("x1", x(crispValue))
        .attr("x2", x(crispValue))
        .attr("y1", 0)
        .attr("y2", innerH)
        .attr("stroke", "#f8fafc")
        .attr("stroke-width", 1.5)
        .attr("stroke-dasharray", "3,3")

      varDef.terms.forEach((term, i) => {
        const color = INPUT_TERM_COLORS[i % INPUT_TERM_COLORS.length]
        const degree = degrees[term.name] ?? 0
        if (degree <= 0.005) return

        g.append("circle")
          .attr("cx", x(crispValue))
          .attr("cy", y(degree))
          .attr("r", 5)
          .attr("fill", color)
          .attr("stroke", "#f8fafc")
          .attr("stroke-width", 1.5)

        const leftSide = x(crispValue) > innerW / 2
        g.append("text")
          .attr("x", x(crispValue) + (leftSide ? -8 : 8))
          .attr("y", y(degree) + 3)
          .attr("fill", "#e5e7eb")
          .attr("font-size", 10)
          .attr("font-family", "ui-monospace, monospace")
          .attr("text-anchor", leftSide ? "end" : "start")
          .text(d3.format(".2f")(degree))
      })
    }

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(5))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 9))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(3).tickFormat(d3.format(".0%")))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 9))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))
  },

  renderRulesPanel(container, rules) {
    const panel = container.append("div")
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    const header = panel.append("div")
      .attr("class", "flex items-baseline justify-between mb-2")

    header.append("span")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500")
      .text("rule firing · bar color = consequent fan term")

    const legend = header.append("div")
      .style("display", "flex")
      .style("gap", "10px")

    Object.entries(FAN_COLORS).forEach(([name, color]) => {
      const item = legend.append("span")
        .attr("class", "inline-flex items-center gap-1 text-[10px] text-gray-400")
      item.append("span")
        .style("width", "8px")
        .style("height", "8px")
        .style("background", color)
        .style("border-radius", "2px")
        .style("display", "inline-block")
      item.append("span").text(name)
    })

    const rowH = 24
    const margin = { top: 6, right: 16, bottom: 6, left: 16 }
    const height = rules.length * rowH + margin.top + margin.bottom
    const innerW = WIDTH - margin.left - margin.right
    const innerH = height - margin.top - margin.bottom

    const svg = panel.append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const labelW = 440
    const thenX = 320
    const valueW = 44
    const barAreaW = innerW - labelW - valueW - 12

    const y = d3.scaleBand()
      .domain(rules.map((_, i) => i))
      .range([0, innerH])
      .padding(0.22)

    const xs = d3.scaleLinear().domain([0, 1]).range([0, barAreaW])

    rules.forEach((r, i) => {
      const color = FAN_COLORS[r.output_term] || "#6b7280"
      const strength = r.strength || 0
      const active = strength > 0.01
      const yy = y(i)
      const bw = y.bandwidth()

      g.append("rect")
        .attr("x", labelW)
        .attr("y", yy)
        .attr("width", barAreaW)
        .attr("height", bw)
        .attr("fill", "#111827")
        .attr("stroke", "#1f2937")

      const [ifPart, thenPart] = r.text.split(/ THEN /)
      const textColor = active ? "#e5e7eb" : "#6b7280"
      const textY = yy + bw / 2 + 3

      g.append("text")
        .attr("x", thenX - 6)
        .attr("y", textY)
        .attr("fill", textColor)
        .attr("font-size", 10)
        .attr("font-family", "ui-monospace, monospace")
        .attr("text-anchor", "end")
        .text(ifPart)

      g.append("text")
        .attr("x", thenX + 6)
        .attr("y", textY)
        .attr("fill", textColor)
        .attr("font-size", 10)
        .attr("font-family", "ui-monospace, monospace")
        .attr("text-anchor", "start")
        .text(thenPart ? `THEN ${thenPart}` : "")

      if (active) {
        g.append("rect")
          .attr("x", labelW)
          .attr("y", yy)
          .attr("width", xs(strength))
          .attr("height", bw)
          .attr("fill", color)
          .attr("fill-opacity", 0.85)
      } else {
        g.append("rect")
          .attr("x", labelW + 1)
          .attr("y", yy + 1)
          .attr("width", barAreaW - 2)
          .attr("height", bw - 2)
          .attr("fill", "none")
          .attr("stroke", color)
          .attr("stroke-opacity", 0.3)
          .attr("stroke-dasharray", "2,2")
      }

      g.append("text")
        .attr("x", labelW + barAreaW + 8)
        .attr("y", yy + bw / 2 + 3)
        .attr("fill", active ? color : "#6b7280")
        .attr("font-size", 10)
        .attr("font-family", "ui-monospace, monospace")
        .attr("font-weight", active ? "600" : "400")
        .text(d3.format(".2f")(strength))
    })
  },

  renderOutputPanel(container, varDef, aggCurve, crispValue, rules) {
    const panel = container.append("div")
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    panel.append("div")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1")
      .text(`${varDef.name.replace(/_/g, " ")} · aggregated output`)

    const panelH = 240
    const margin = { top: 28, right: 16, bottom: 46, left: 44 }
    const innerW = WIDTH - margin.left - margin.right
    const innerH = panelH - margin.top - margin.bottom

    const svg = panel.append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${panelH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleLinear().domain(varDef.bounds).range([0, innerW])
    const y = d3.scaleLinear().domain([0, 1]).range([innerH, 0])

    varDef.terms.forEach(term => {
      const color = FAN_COLORS[term.name] || "#6b7280"
      const samples = sampleMf(term, varDef.bounds)

      g.append("path")
        .attr("d", d3.line().x(d => x(d[0])).y(d => y(d[1]))(samples))
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "2,3")
        .attr("opacity", 0.5)

      g.append("text")
        .attr("x", x(term.params[1]))
        .attr("y", -8)
        .attr("fill", color)
        .attr("font-size", 10)
        .attr("font-weight", "600")
        .attr("text-anchor", "middle")
        .text(term.name)
    })

    const termByName = Object.fromEntries(varDef.terms.map(t => [t.name, t]))
    const area = d3.area()
      .x(d => x(d[0]))
      .y0(y(0))
      .y1(d => y(d[1]))

    rules
      .filter(r => (r.strength || 0) > 0.005 && termByName[r.output_term])
      .forEach(r => {
        const term = termByName[r.output_term]
        const color = FAN_COLORS[r.output_term] || "#6b7280"
        const clipped = clipTriangle(term, varDef.bounds, r.strength)

        g.append("path")
          .attr("d", area(clipped))
          .attr("fill", color)
          .attr("fill-opacity", 0.22)
      })

    if (aggCurve && aggCurve.length > 0) {
      g.append("path")
        .attr("d", area(aggCurve))
        .attr("fill", "#f8fafc")
        .attr("fill-opacity", 0.08)

      g.append("path")
        .attr("d", d3.line().x(d => x(d[0])).y(d => y(d[1]))(aggCurve))
        .attr("fill", "none")
        .attr("stroke", "#f8fafc")
        .attr("stroke-width", 2.25)
    }

    if (typeof crispValue === "number") {
      g.append("line")
        .attr("x1", x(crispValue))
        .attr("x2", x(crispValue))
        .attr("y1", 0)
        .attr("y2", innerH)
        .attr("stroke", "#fbbf24")
        .attr("stroke-width", 2)

      g.append("circle")
        .attr("cx", x(crispValue))
        .attr("cy", innerH)
        .attr("r", 7)
        .attr("fill", "#fbbf24")
        .attr("stroke", "#0b1220")
        .attr("stroke-width", 2)

      g.append("text")
        .attr("x", x(crispValue))
        .attr("y", innerH + 36)
        .attr("fill", "#fbbf24")
        .attr("font-size", 11)
        .attr("font-family", "ui-monospace, monospace")
        .attr("font-weight", "600")
        .attr("text-anchor", "middle")
        .text(`centroid ${d3.format(".1f")(crispValue)}`)
    }

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(6))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(3).tickFormat(d3.format(".0%")))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))
  }
}
