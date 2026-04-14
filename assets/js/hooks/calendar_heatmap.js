import * as d3 from "d3"

/** Calendar grid colored by dominant cluster, with gap and selection highlighting. */
const CELL_SIZE = 13
const CELL_GAP = 2
const CELL_STEP = CELL_SIZE + CELL_GAP
const YEAR_PADDING = 24
const LEFT_MARGIN = 30
const TOP_MARGIN = 20

export const CalendarHeatmap = {
  mounted() {
    this.svg = null
    this.tooltip = null
    this.data = { days: [], clusterColors: {}, clusterNames: {}, transitionDates: [] }
    this.transitionSet = new Set()

    this.handleEvent("update-calendar", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("highlight-calendar", ({ dates }) => {
      this.highlightDates(dates)
    })

    this.handleEvent("highlight-calendar-gap", ({ start, length }) => {
      this.highlightGap(start, length)
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { days, clusterColors } = this.data
    if (!days || days.length === 0) return

    this.transitionSet = new Set(this.data.transitionDates || [])

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    // Build tooltip — anchored in the right margin
    this.tooltip = d3.select(this.el)
      .append("div")
      .attr("class", "calendar-tooltip")
      .style("position", "absolute")
      .style("right", "0px")
      .style("pointer-events", "none")
      .style("background", "rgba(10,10,26,0.92)")
      .style("color", "#eee")
      .style("padding", "10px 14px")
      .style("border-radius", "8px")
      .style("border", "1px solid rgba(255,255,255,0.06)")
      .style("box-shadow", "0 4px 16px rgba(0,0,0,0.4)")
      .style("font-size", "12px")
      .style("line-height", "1.5")
      .style("white-space", "nowrap")
      .style("z-index", "100")
      .style("opacity", 0)

    // Group days by year
    const byYear = d3.group(days, d => d.date.slice(0, 4))
    const years = Array.from(byYear.keys()).sort()

    const width = LEFT_MARGIN + 53 * CELL_STEP + 20
    const height = TOP_MARGIN + years.length * (7 * CELL_STEP + YEAR_PADDING)

    this.svg = d3.select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", height)

    // Hatching pattern for gaps
    const defs = this.svg.append("defs")
    const pattern = defs.append("pattern")
      .attr("id", "gap-hatch")
      .attr("width", 4)
      .attr("height", 4)
      .attr("patternUnits", "userSpaceOnUse")
      .attr("patternTransform", "rotate(45)")
    pattern.append("line")
      .attr("x1", 0).attr("y1", 0)
      .attr("x2", 0).attr("y2", 4)
      .attr("stroke", "#555")
      .attr("stroke-width", 1)

    // Day labels
    const dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    years.forEach((year, yi) => {
      const yOffset = TOP_MARGIN + yi * (7 * CELL_STEP + YEAR_PADDING)

      // Year label
      this.svg.append("text")
        .attr("x", 0)
        .attr("y", yOffset + 3.5 * CELL_STEP)
        .attr("text-anchor", "start")
        .attr("fill", "#888")
        .attr("font-size", "11px")
        .attr("font-weight", "bold")
        .text(year)

      if (yi === 0) {
        dayLabels.forEach((label, di) => {
          if (label) {
            this.svg.append("text")
              .attr("x", LEFT_MARGIN - 4)
              .attr("y", yOffset + di * CELL_STEP + CELL_SIZE - 1)
              .attr("text-anchor", "end")
              .attr("fill", "#666")
              .attr("font-size", "9px")
              .text(label)
          }
        })
      }

      const yearDays = byYear.get(year)
      const g = this.svg.append("g")
        .attr("transform", `translate(${LEFT_MARGIN}, ${yOffset})`)

      g.selectAll("rect")
        .data(yearDays)
        .join("rect")
        .attr("class", "day-cell")
        .attr("data-date", d => d.date)
        .attr("width", CELL_SIZE)
        .attr("height", CELL_SIZE)
        .attr("rx", 2)
        .attr("x", d => {
          const date = new Date(d.date + "T00:00:00")
          const jan1 = new Date(date.getFullYear(), 0, 1)
          const weekNum = Math.floor((d3.timeDay.count(jan1, date) + jan1.getDay()) / 7)
          return weekNum * CELL_STEP
        })
        .attr("y", d => {
          const date = new Date(d.date + "T00:00:00")
          return date.getDay() * CELL_STEP
        })
        .attr("fill", d => this.cellColor(d, clusterColors))
        .attr("stroke", d => this.cellStroke(d, clusterColors))
        .attr("stroke-width", d => this.cellStrokeWidth(d))
        .attr("stroke-dasharray", d => d.isGap ? "2,1" : "none")
        .style("cursor", d => d.isGap ? "default" : "pointer")
        .on("mouseenter", (event, d) => this.showTooltip(event, d, clusterColors))
        .on("mouseleave", () => this.hideTooltip())
        .on("click", (event, d) => {
          if (!d.isGap) {
            this.pushEvent("day_selected", { date: d.date })
          }
        })
    })
  },

  cellColor(day, clusterColors) {
    if (day.isGap) {
      return Object.keys(day.memberships || {}).length > 0
        ? this.dominantColor(day.memberships, clusterColors, 0.3)
        : "url(#gap-hatch)"
    }

    const mems = day.memberships || {}
    const entries = Object.entries(mems)
    if (entries.length === 0) return "#2a2a2a"

    return this.dominantColor(mems, clusterColors, 1.0)
  },

  topMembership(memberships) {
    const entries = Object.entries(memberships || {})
    if (entries.length === 0) return [null, 0]
    return entries.reduce((a, b) => b[1] > a[1] ? b : a)
  },

  dominantColor(memberships, clusterColors, baseOpacity) {
    const entries = Object.entries(memberships)
    if (entries.length === 0) return "#2a2a2a"

    const [topCluster, topWeight] = entries.reduce((a, b) => b[1] > a[1] ? b : a)
    const color = d3.color(clusterColors[topCluster] || "#666")
    if (!color) return "#2a2a2a"

    // Real curve: weak membership → faint, strong → vivid. No floor.
    const alpha = baseOpacity * (0.12 + 0.88 * Math.pow(topWeight, 1.5))
    return `rgba(${color.r}, ${color.g}, ${color.b}, ${alpha})`
  },

  cellStroke(day, clusterColors) {
    if (this.transitionSet.has(day.date)) return "#fff"
    if (day.isGap) return "#555"
    const [topCluster, weight] = this.topMembership(day.memberships)
    if (!topCluster || weight < 0.5) return "none"
    return clusterColors[topCluster] || "none"
  },

  cellStrokeWidth(day) {
    if (this.transitionSet.has(day.date)) return 2
    if (day.isGap) return 0.5
    const [, weight] = this.topMembership(day.memberships)
    if (weight >= 0.65) return 1.5
    if (weight >= 0.5) return 0.75
    return 0
  },

  showTooltip(event, day, clusterColors) {
    let html = `<strong style="font-size:13px">${day.date}</strong>`

    if (day.isGap) {
      html += `<br><span style="color:#666;font-style:italic">gap day</span>`
    }

    if (day.dimensions) {
      html += `<div style="margin-top:6px; display:grid; grid-template-columns:auto auto; gap:1px 10px">`
      for (const [key, val] of Object.entries(day.dimensions)) {
        html += `<span style="color:#888">${key}</span><strong>${val}</strong>`
      }
      html += `</div>`
    }

    const mems = day.memberships || {}
    const sorted = Object.entries(mems).sort((a, b) => b[1] - a[1])
    if (sorted.length > 0) {
      html += `<div style="margin-top:6px; border-top:1px solid rgba(255,255,255,0.08); padding-top:5px">`
      const clusterNames = this.data.clusterNames || {}
      for (const [cluster, val] of sorted) {
        const color = clusterColors[cluster] || "#888"
        const name = clusterNames[cluster] || cluster
        const pct = (val * 100).toFixed(0)
        const barW = Math.round(val * 50)
        html += `<div style="display:flex; align-items:center; gap:5px; margin:2px 0">
          <span style="color:${color}; font-size:11px; white-space:nowrap">${name}</span>
          <div style="flex:0 0 50px; height:3px; background:rgba(255,255,255,0.06); border-radius:2px">
            <div style="width:${barW}px; height:3px; background:${color}; border-radius:2px"></div>
          </div>
          <span style="color:#888; font-size:10px; white-space:nowrap">${pct}%</span>
        </div>`
      }
      html += `</div>`
    }

    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("top", (event.clientY - rect.top - 10) + "px")
      .style("opacity", 1)
  },

  hideTooltip() {
    this.tooltip.style("opacity", 0)
  },

  highlightDates(dates) {
    if (!this.svg) return
    const dateSet = new Set(dates)

    this.svg.selectAll(".day-cell")
      .attr("opacity", d => {
        if (dates.length === 0) return 1
        return dateSet.has(d.date) ? 1 : 0.15
      })
  },

  highlightGap(start, length) {
    if (!this.svg) return
    const startDate = new Date(start + "T00:00:00")
    const gapDates = new Set()
    for (let i = 0; i < length; i++) {
      const d = new Date(startDate)
      d.setDate(d.getDate() + i)
      gapDates.add(d.toISOString().slice(0, 10))
    }

    this.svg.selectAll(".day-cell")
      .attr("opacity", d => gapDates.has(d.date) ? 1 : 0.15)
      .attr("stroke", d => {
        if (gapDates.has(d.date)) return "#f39c12"
        return this.cellStroke(d, this.data.clusterColors)
      })
      .attr("stroke-width", d => {
        if (gapDates.has(d.date)) return 2
        return this.cellStrokeWidth(d)
      })
  },

  isolate(cluster) {
    if (!this.svg) return

    if (!cluster) {
      this.svg.selectAll(".day-cell").attr("opacity", 1)
      return
    }

    this.svg.selectAll(".day-cell")
      .attr("opacity", d => {
        const mem = (d.memberships || {})[cluster] || 0
        if (mem >= 0.3) return 1
        return 0.08
      })
  },

  destroyed() {
    if (this.tooltip) this.tooltip.remove()
  }
}
