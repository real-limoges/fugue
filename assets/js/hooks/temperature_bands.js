import * as d3 from "d3"

const WIDTH = 820
const SHAPES_H = 130
const BANDS_H = 260
const MARGIN = { top: 18, right: 14, bottom: 26, left: 44 }

function triangular(x, a, b, c) {
  if (x <= a || x >= c) return 0
  if (x === b) return 1
  if (x < b) return b === a ? 1 : (x - a) / (b - a)
  return c === b ? 1 : (c - x) / (c - b)
}

function sampleTriangle(mf, bounds, steps = 80) {
  const [lo, hi] = bounds
  const out = []
  for (let i = 0; i <= steps; i++) {
    const x = lo + (i / steps) * (hi - lo)
    out.push([x, triangular(x, mf.a, mf.b, mf.c)])
  }
  return out
}

export const TemperatureBands = {
  mounted() {
    this.data = null
    this.el.style.position = "relative"

    this.handleEvent("update-bands", (data) => {
      this.data = data
      this.render()
    })

    this.pushEvent("sandbox:bands_ready", {})
  },

  render() {
    if (!this.data || !this.data.series || this.data.series.length === 0) return
    const { series, mfs, bounds } = this.data

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    const container = d3.select(this.el)
      .append("div")
      .style("display", "flex")
      .style("flex-direction", "column")
      .style("gap", "14px")

    this.renderShapesPanel(container, mfs, bounds)
    this.renderBandsPanel(container, series, mfs)
  },

  renderShapesPanel(container, mfs, bounds) {
    const panel = container.append("div")

    panel.append("div")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1")
      .text("membership functions · drag sliders to reshape")

    const innerW = WIDTH - MARGIN.left - MARGIN.right
    const innerH = SHAPES_H - MARGIN.top - MARGIN.bottom

    const svg = panel.append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${SHAPES_H}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const x = d3.scaleLinear().domain(bounds).range([0, innerW])
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

    mfs.forEach(mf => {
      const samples = sampleTriangle(mf, bounds)
      g.append("path")
        .attr("d", area(samples))
        .attr("fill", mf.color)
        .attr("fill-opacity", 0.18)

      g.append("path")
        .attr("d", line(samples))
        .attr("fill", "none")
        .attr("stroke", mf.color)
        .attr("stroke-width", 1.75)

      g.append("text")
        .attr("x", x(mf.b))
        .attr("y", y(1) - 5)
        .attr("fill", mf.color)
        .attr("font-size", 11)
        .attr("font-weight", "600")
        .attr("text-anchor", "middle")
        .text(mf.name)
    })

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(9).tickFormat(d => `${d}°`))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))
  },

  renderBandsPanel(container, series, mfs) {
    const panel = container.append("div")
      .style("position", "relative")

    panel.append("div")
      .attr("class", "text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1")
      .text("fuzzy memberships over time · hover for breakdown")

    const innerW = WIDTH - MARGIN.left - MARGIN.right
    const innerH = BANDS_H - MARGIN.top - MARGIN.bottom

    const svg = panel.append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${BANDS_H}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("display", "block")

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    const parseDate = d3.timeParse("%Y-%m-%d")
    const data = series.map(d => ({ date: parseDate(d.date), ...d.memberships }))
    const names = mfs.map(mf => mf.name)
    const colors = Object.fromEntries(mfs.map(mf => [mf.name, mf.color]))

    const x = d3.scaleTime()
      .domain(d3.extent(data, d => d.date))
      .range([0, innerW])

    const y = d3.scaleLinear()
      .domain([0, 1])
      .range([innerH, 0])

    const stacked = d3.stack()
      .keys(names)
      .value((d, key) => d[key] || 0)
      .offset(d3.stackOffsetNone)(data)

    const area = d3.area()
      .x(d => x(d.data.date))
      .y0(d => y(d[0]))
      .y1(d => y(d[1]))
      .curve(d3.curveMonotoneX)

    g.selectAll("path.band")
      .data(stacked)
      .join("path")
      .attr("class", "band")
      .attr("d", area)
      .attr("fill", d => colors[d.key] || "#666")
      .attr("opacity", 0.92)

    const [minDate, maxDate] = d3.extent(data, d => d.date)
    const years = d3.timeYear.range(
      d3.timeYear.floor(minDate),
      d3.timeYear.ceil(maxDate)
    )
    g.append("g")
      .attr("class", "year-ticks")
      .selectAll("line")
      .data(years)
      .join("line")
      .attr("x1", d => x(d))
      .attr("x2", d => x(d))
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#ffffff")
      .attr("stroke-opacity", 0.14)
      .attr("stroke-dasharray", "2,3")

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(d3.timeYear.every(1)).tickFormat(d3.timeFormat("%Y")))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(4).tickFormat(d3.format(".0%")))
      .call(sel => sel.selectAll("text").attr("fill", "#9ca3af").attr("font-size", 10))
      .call(sel => sel.selectAll("line").attr("stroke", "#374151"))
      .call(sel => sel.select(".domain").attr("stroke", "#374151"))

    stacked.forEach(s => {
      const lastPoint = s[s.length - 1]
      const mid = (lastPoint[0] + lastPoint[1]) / 2
      const bandHeight = Math.abs(y(lastPoint[1]) - y(lastPoint[0]))
      if (bandHeight < 11) return

      const base = g.append("text")
        .attr("x", innerW - 6)
        .attr("y", y(mid) + 3)
        .attr("font-size", 10)
        .attr("font-weight", "700")
        .attr("text-anchor", "end")
        .attr("paint-order", "stroke")
        .attr("stroke", "#0f172a")
        .attr("stroke-width", 3)
        .attr("stroke-linejoin", "round")
        .attr("fill", colors[s.key])
        .text(s.key)
      base.clone(true)
        .attr("stroke", "none")
    })

    const crosshair = g.append("line")
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#f8fafc")
      .attr("stroke-width", 1)
      .attr("opacity", 0)

    const tooltip = d3.select(this.el)
      .append("div")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "#0f172a")
      .style("border", "1px solid #1f2937")
      .style("border-radius", "6px")
      .style("padding", "8px 10px")
      .style("font-family", "ui-monospace, monospace")
      .style("font-size", "11px")
      .style("color", "#e5e7eb")
      .style("box-shadow", "0 4px 12px rgba(0,0,0,0.4)")
      .style("opacity", 0)
      .style("z-index", "20")

    const bisect = d3.bisector(d => d.date).left
    const hostEl = this.el
    const dateFmt = d3.timeFormat("%Y-%m-%d")

    g.append("rect")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "transparent")
      .on("mousemove", function (event) {
        const [mx] = d3.pointer(event, g.node())
        const d0 = x.invert(mx)
        const idx = Math.max(0, Math.min(data.length - 1, bisect(data, d0)))
        const d = data[idx]

        crosshair
          .attr("x1", x(d.date))
          .attr("x2", x(d.date))
          .attr("opacity", 0.85)

        const rows = names
          .map(name => {
            const pct = Math.round((d[name] || 0) * 100)
            return `<div style="display:flex;justify-content:space-between;gap:14px;">
              <span style="color:${colors[name]};">■ ${name}</span>
              <span style="color:#e5e7eb;">${pct}%</span>
            </div>`
          })
          .join("")

        const [sx, sy] = d3.pointer(event, hostEl)
        tooltip
          .html(
            `<div style="margin-bottom:4px;color:#9ca3af;">${dateFmt(d.date)}</div>${rows}`
          )
          .style("left", `${sx + 14}px`)
          .style("top", `${sy + 14}px`)
          .style("opacity", 1)
      })
      .on("mouseleave", () => {
        crosshair.attr("opacity", 0)
        tooltip.style("opacity", 0)
      })
  }
}
