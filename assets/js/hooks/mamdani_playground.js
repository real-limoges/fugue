import * as d3 from "d3"

const WIDTH = 820

const FAN_COLORS = {
  off: "#9ca3af",
  low: "#60a5fa",
  medium: "#f59e0b",
  high: "#ec4899",
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

    this._onSliderInput = (e) => {
      if (e.target.type !== "range" || !this.data) return
      if (e.target.name !== "temperature" && e.target.name !== "humidity") return
      this._updateInputsLocally()
    }
    document.addEventListener("input", this._onSliderInput)

    this.pushEvent("menagerie:mamdani_ready", {})
  },

  destroyed() {
    if (this._onSliderInput) {
      document.removeEventListener("input", this._onSliderInput)
    }
  },

  _updateInputsLocally() {
    if (!this.data) return

    const tempEl = document.querySelector('input[name="temperature"]')
    const humEl = document.querySelector('input[name="humidity"]')
    if (!tempEl || !humEl) return

    const values = { temperature: parseFloat(tempEl.value), humidity: parseFloat(humEl.value) }
    const inputVars = this.data.mfs.inputs || []

    const degrees = {}
    inputVars.forEach((varDef) => {
      degrees[varDef.name] = {}
      varDef.terms.forEach((term) => {
        degrees[varDef.name][term.name] = triangular(values[varDef.name], term.params)
      })
    })

    inputVars.forEach((varDef) => {
      const panelEl = d3.select(this.el).select(`[data-var="${varDef.name}"]`)
      if (panelEl.empty()) return

      const scales = panelEl.node().__scales
      if (!scales) return

      const crispValue = values[varDef.name]

      panelEl
        .select(".input-crisp-readout")
        .text(typeof crispValue === "number" ? d3.format(".1f")(crispValue) : "—")

      const g = panelEl.select("svg g")
      this._renderInputDynamics(g, varDef, crispValue, degrees[varDef.name] || {}, scales)
    })
  },

  _renderInputDynamics(g, varDef, crispValue, degrees, { x, y, innerW, innerH }) {
    g.select(".input-dynamics").remove()

    if (typeof crispValue !== "number") return

    const dyn = g.append("g").attr("class", "input-dynamics")

    dyn
      .append("line")
      .attr("x1", x(crispValue))
      .attr("x2", x(crispValue))
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#f8fafc")
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "3,3")

    const degreeData = []
    varDef.terms.forEach((term, i) => {
      const color = INPUT_TERM_COLORS[i % INPUT_TERM_COLORS.length]
      const degree = degrees[term.name] ?? 0
      if (degree <= 0.005) return

      dyn
        .append("circle")
        .attr("cx", x(crispValue))
        .attr("cy", y(degree))
        .attr("r", 5)
        .attr("fill", color)
        .attr("stroke", "#f8fafc")
        .attr("stroke-width", 1.5)

      degreeData.push({ color, degree, text: d3.format(".2f")(degree), y: y(degree) + 3 })
    })

    degreeData.sort((a, b) => a.y - b.y)
    const minGap = 13
    for (let i = 1; i < degreeData.length; i++) {
      if (degreeData[i].y - degreeData[i - 1].y < minGap) {
        degreeData[i].y = degreeData[i - 1].y + minGap
      }
    }
    for (let i = degreeData.length - 1; i >= 0; i--) {
      if (degreeData[i].y > innerH + 3) degreeData[i].y = innerH + 3
      if (i > 0 && degreeData[i].y - degreeData[i - 1].y < minGap) {
        degreeData[i - 1].y = degreeData[i].y - minGap
      }
    }

    const leftSide = x(crispValue) > innerW / 2
    degreeData.forEach((d) => {
      dyn
        .append("text")
        .attr("x", x(crispValue) + (leftSide ? -8 : 8))
        .attr("y", d.y)
        .attr("fill", "#e5e7eb")
        .attr("font-size", 10)
        .attr("font-family", "ui-monospace, monospace")
        .attr("text-anchor", leftSide ? "end" : "start")
        .text(d.text)
    })
  },

  render() {
    if (!this.data) {
      this.el.innerHTML = `<div class="py-12 text-center text-xs italic text-gray-500">awaiting inference…</div>`
      return
    }

    const { mfs, rules, inputs, input_degrees, output_curves, crisp } = this.data

    // Create the stable container structure once
    let container = d3.select(this.el).select(".mamdani-container")
    if (container.empty()) {
      this.el.innerHTML = ""
      container = d3
        .select(this.el)
        .append("div")
        .attr("class", "mamdani-container")
        .style("display", "flex")
        .style("flex-direction", "column")
        .style("gap", "16px")

      container
        .append("div")
        .attr("class", "mamdani-input-row")
        .style("display", "grid")
        .style("grid-template-columns", "1fr 1fr")
        .style("gap", "12px")

      container.append("div").attr("class", "mamdani-rules")
      container.append("div").attr("class", "mamdani-output")
    }

    // Input panels: build statics once, always update dynamics
    const inputRow = container.select(".mamdani-input-row")
    const inputVars = mfs.inputs || []
    const needsInputBuild = inputRow.select("[data-var]").empty()

    if (needsInputBuild) {
      inputRow.selectAll("*").remove()
      inputVars.forEach((varDef) => {
        this._buildInputPanel(inputRow, varDef)
      })
    }

    inputVars.forEach((varDef) => {
      const panelEl = inputRow.select(`[data-var="${varDef.name}"]`)
      if (panelEl.empty()) return
      const scales = panelEl.node().__scales
      if (!scales) return

      panelEl
        .select(".input-crisp-readout")
        .text(typeof inputs[varDef.name] === "number" ? d3.format(".1f")(inputs[varDef.name]) : "—")

      const g = panelEl.select("svg g")
      this._renderInputDynamics(
        g,
        varDef,
        inputs[varDef.name],
        input_degrees[varDef.name] || {},
        scales
      )
    })

    // Rules and output: always rebuild from server data
    const rulesSection = container.select(".mamdani-rules")
    rulesSection.selectAll("*").remove()
    this.renderRulesPanel(rulesSection, rules || [])

    const outputSection = container.select(".mamdani-output")
    outputSection.selectAll("*").remove()
    const outputVar = (mfs.outputs || [])[0]
    if (outputVar) {
      const aggCurve = (output_curves || {})[outputVar.name] || []
      const crispValue = (crisp || {})[outputVar.name]
      this.renderOutputPanel(outputSection, outputVar, aggCurve, crispValue, rules || [])
    }
  },

  _buildInputPanel(parent, varDef) {
    const panel = parent
      .append("div")
      .attr("data-var", varDef.name)
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    const header = panel.append("div").attr("class", "flex items-baseline justify-between mb-1")

    header
      .append("span")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500")
      .text(`${varDef.name.replace(/_/g, " ")} fuzzification`)

    header
      .append("span")
      .attr(
        "class",
        "input-crisp-readout font-mono text-lg font-semibold tabular-nums text-gray-100"
      )
      .text("—")

    const panelW = 400
    const panelH = 176
    const margin = { top: 26, right: 18, bottom: 24, left: 42 }
    const innerW = panelW - margin.left - margin.right
    const innerH = panelH - margin.top - margin.bottom

    const svg = panel
      .append("svg")
      .attr("viewBox", `0 0 ${panelW} ${panelH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleLinear().domain(varDef.bounds).range([0, innerW])
    const y = d3.scaleLinear().domain([0, 1]).range([innerH, 0])

    // Store scales for later dynamic updates
    panel.node().__scales = { x, y, innerW, innerH }

    g.append("line")
      .attr("x1", 0)
      .attr("x2", innerW)
      .attr("y1", innerH)
      .attr("y2", innerH)
      .attr("stroke", "#374151")

    const line = d3
      .line()
      .x((d) => x(d[0]))
      .y((d) => y(d[1]))
    const area = d3
      .area()
      .x((d) => x(d[0]))
      .y0(y(0))
      .y1((d) => y(d[1]))

    // --- static: triangle shapes + term name labels ---
    const charW = 6
    const termLabels = varDef.terms.map((term, i) => {
      const color = INPUT_TERM_COLORS[i % INPUT_TERM_COLORS.length]
      const samples = sampleMf(term, varDef.bounds)

      g.append("path").attr("d", area(samples)).attr("fill", color).attr("fill-opacity", 0.12)

      g.append("path")
        .attr("d", line(samples))
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-opacity", 0.85)

      const peakPx = x(term.params[1])
      const nearLeft = peakPx < 24
      const nearRight = peakPx > innerW - 24
      const anchor = nearLeft ? "start" : nearRight ? "end" : "middle"
      const lx = nearLeft ? 0 : nearRight ? innerW : peakPx
      const textW = term.name.length * charW
      const left = anchor === "start" ? lx : anchor === "end" ? lx - textW : lx - textW / 2
      return { name: term.name, color, x: lx, anchor, left, right: left + textW, y: -10 }
    })

    termLabels.sort((a, b) => a.left - b.left)
    for (let i = 1; i < termLabels.length; i++) {
      if (termLabels[i].left < termLabels[i - 1].right + 4) {
        termLabels[i].y = termLabels[i - 1].y === -10 ? -22 : -10
      }
    }

    termLabels.forEach((d) => {
      g.append("text")
        .attr("x", d.x)
        .attr("y", d.y)
        .attr("fill", d.color)
        .attr("font-size", 10)
        .attr("font-weight", "600")
        .attr("text-anchor", d.anchor)
        .text(d.name)
    })

    // --- static: axes ---
    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(5))
      .call((sel) => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 9))
      .call((sel) => sel.selectAll("line").attr("stroke", "#374151"))
      .call((sel) => sel.select(".domain").attr("stroke", "#374151"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(3).tickFormat(d3.format(".0%")))
      .call((sel) => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 9))
      .call((sel) => sel.selectAll("line").attr("stroke", "#374151"))
      .call((sel) => sel.select(".domain").attr("stroke", "#374151"))
  },

  renderRulesPanel(container, rules) {
    const panel = container
      .append("div")
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    const header = panel.append("div").attr("class", "flex items-baseline justify-between mb-2")

    header
      .append("span")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500")
      .text("rule firing · bar color = consequent fan term")

    const legend = header.append("div").style("display", "flex").style("gap", "10px")

    Object.entries(FAN_COLORS).forEach(([name, color]) => {
      const item = legend
        .append("span")
        .attr("class", "inline-flex items-center gap-1 text-[10px] text-gray-400")
      item
        .append("span")
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

    const svg = panel
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    const labelW = 440
    const thenX = 320
    const valueW = 44
    const barAreaW = innerW - labelW - valueW - 12

    const y = d3
      .scaleBand()
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
    const panel = container
      .append("div")
      .style("background", "#0b1220")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "8px")
      .style("padding", "12px 14px")

    panel
      .append("div")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1")
      .text(`${varDef.name.replace(/_/g, " ")} · aggregated output`)

    const panelH = 240
    const margin = { top: 28, right: 16, bottom: 46, left: 44 }
    const innerW = WIDTH - margin.left - margin.right
    const innerH = panelH - margin.top - margin.bottom

    const svg = panel
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${panelH}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleLinear().domain(varDef.bounds).range([0, innerW])
    const y = d3.scaleLinear().domain([0, 1]).range([innerH, 0])

    const charW = 6
    const outputLabels = varDef.terms.map((term) => {
      const color = FAN_COLORS[term.name] || "#6b7280"
      const samples = sampleMf(term, varDef.bounds)

      g.append("path")
        .attr(
          "d",
          d3
            .line()
            .x((d) => x(d[0]))
            .y((d) => y(d[1]))(samples)
        )
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "2,3")
        .attr("opacity", 0.5)

      const peakPx = x(term.params[1])
      const nearLeft = peakPx < 24
      const nearRight = peakPx > innerW - 24
      const anchor = nearLeft ? "start" : nearRight ? "end" : "middle"
      const lx = nearLeft ? 0 : nearRight ? innerW : peakPx
      const textW = term.name.length * charW
      const left = anchor === "start" ? lx : anchor === "end" ? lx - textW : lx - textW / 2
      return { name: term.name, color, x: lx, anchor, left, right: left + textW, y: -8 }
    })

    outputLabels.sort((a, b) => a.left - b.left)
    for (let i = 1; i < outputLabels.length; i++) {
      if (outputLabels[i].left < outputLabels[i - 1].right + 4) {
        outputLabels[i].y = outputLabels[i - 1].y === -8 ? -20 : -8
      }
    }

    outputLabels.forEach((d) => {
      g.append("text")
        .attr("x", d.x)
        .attr("y", d.y)
        .attr("fill", d.color)
        .attr("font-size", 10)
        .attr("font-weight", "600")
        .attr("text-anchor", d.anchor)
        .text(d.name)
    })

    const termByName = Object.fromEntries(varDef.terms.map((t) => [t.name, t]))
    const area = d3
      .area()
      .x((d) => x(d[0]))
      .y0(y(0))
      .y1((d) => y(d[1]))

    rules
      .filter((r) => (r.strength || 0) > 0.005 && termByName[r.output_term])
      .forEach((r) => {
        const term = termByName[r.output_term]
        const color = FAN_COLORS[r.output_term] || "#6b7280"
        const clipped = clipTriangle(term, varDef.bounds, r.strength)

        g.append("path").attr("d", area(clipped)).attr("fill", color).attr("fill-opacity", 0.22)
      })

    if (aggCurve && aggCurve.length > 0) {
      g.append("path").attr("d", area(aggCurve)).attr("fill", "#f8fafc").attr("fill-opacity", 0.08)

      g.append("path")
        .attr(
          "d",
          d3
            .line()
            .x((d) => x(d[0]))
            .y((d) => y(d[1]))(aggCurve)
        )
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

      const centroidText = `centroid ${d3.format(".1f")(crispValue)}`
      const centroidW = centroidText.length * 6.6
      const cx = x(crispValue)
      const cNearLeft = cx < centroidW / 2
      const cNearRight = cx > innerW - centroidW / 2
      g.append("text")
        .attr("x", cNearLeft ? 0 : cNearRight ? innerW : cx)
        .attr("y", innerH + 36)
        .attr("fill", "#fbbf24")
        .attr("font-size", 11)
        .attr("font-family", "ui-monospace, monospace")
        .attr("font-weight", "600")
        .attr("text-anchor", cNearLeft ? "start" : cNearRight ? "end" : "middle")
        .text(centroidText)
    }

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(6))
      .call((sel) => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call((sel) => sel.selectAll("line").attr("stroke", "#374151"))
      .call((sel) => sel.select(".domain").attr("stroke", "#374151"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(3).tickFormat(d3.format(".0%")))
      .call((sel) => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call((sel) => sel.selectAll("line").attr("stroke", "#374151"))
      .call((sel) => sel.select(".domain").attr("stroke", "#374151"))
  },
}
