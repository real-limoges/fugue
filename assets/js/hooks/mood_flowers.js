import * as d3 from "d3"

/** Grid of monthly mood-flower radars. Shape encodes raw dimensions, fill color encodes the modal cluster for the month. */
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

export const MoodFlowers = {
  mounted() {
    this.data = { flowers: [], dimensions: [], clusterColors: {}, clusterNames: {} }

    this.handleEvent("update-flowers", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { flowers, dimensions, clusterColors } = this.data
    if (!flowers || flowers.length === 0 || !dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    this.tooltip = d3.select(this.el)
      .append("div")
      .attr("class", "flower-tooltip")
      .style("position", "absolute")
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

    const byYear = d3.group(flowers, f => f.month.slice(0, 4))
    const years = Array.from(byYear.keys()).sort()

    const grid = d3.select(this.el)
      .append("div")
      .style("display", "grid")
      .style("grid-template-columns", "auto repeat(12, 1fr)")
      .style("gap", "8px 6px")
      .style("align-items", "center")
      .style("margin-top", "4px")

    // Header row: empty corner + month abbreviations
    grid.append("div")
    MONTH_NAMES.forEach(m => {
      grid.append("div")
        .style("text-align", "center")
        .style("color", "#666")
        .style("font-size", "10px")
        .style("font-weight", "600")
        .style("letter-spacing", "0.5px")
        .text(m)
    })

    const numDims = dimensions.length
    const angleSlice = (Math.PI * 2) / numDims
    const hook = this

    years.forEach(year => {
      grid.append("div")
        .style("color", "#888")
        .style("font-size", "13px")
        .style("font-weight", "700")
        .style("padding-right", "8px")
        .style("text-align", "right")
        .text(year)

      const yearFlowers = byYear.get(year)
      const flowerByMonth = new Map(yearFlowers.map(f => [f.month, f]))

      MONTH_NAMES.forEach((_, mi) => {
        const monthKey = `${year}-${String(mi + 1).padStart(2, "0")}`
        const flower = flowerByMonth.get(monthKey)

        const cell = grid.append("div")
          .style("aspect-ratio", "1 / 1")
          .style("position", "relative")

        if (!flower) {
          cell.append("div")
            .style("width", "100%")
            .style("height", "100%")
            .style("border-radius", "50%")
            .style("border", "1px dashed rgba(255,255,255,0.05)")
            .style("box-sizing", "border-box")
          return
        }

        const color = (flower.cluster && clusterColors[flower.cluster]) || "#888"
        const values = dimensions.map(d => flower.values[d] || 0)

        const svg = cell.append("svg")
          .attr("viewBox", "0 0 100 100")
          .attr("preserveAspectRatio", "xMidYMid meet")
          .style("width", "100%")
          .style("height", "100%")
          .style("display", "block")
          .style("cursor", "pointer")

        const g = svg.append("g")
          .attr("transform", "translate(50, 50)")

        const R = 40

        g.append("circle")
          .attr("r", R)
          .attr("fill", "none")
          .attr("stroke", "rgba(255,255,255,0.06)")
          .attr("stroke-width", 0.5)

        g.append("circle")
          .attr("r", R * 0.5)
          .attr("fill", "none")
          .attr("stroke", "rgba(255,255,255,0.04)")
          .attr("stroke-width", 0.5)

        const lineGen = d3.lineRadial()
          .angle((_, i) => angleSlice * i)
          .radius(d => d * R)
          .curve(d3.curveCardinalClosed.tension(0.5))

        g.append("path")
          .datum(values)
          .attr("d", lineGen)
          .attr("fill", color)
          .attr("fill-opacity", 0.55)
          .attr("stroke", color)
          .attr("stroke-width", 1.5)
          .attr("stroke-linejoin", "round")

        cell
          .on("mouseenter", function(event) { hook.showTooltip(event, flower, color) })
          .on("mouseleave", function() { hook.hideTooltip() })
      })
    })
  },

  showTooltip(event, flower, color) {
    const dims = flower.raw || {}
    const clusterName = flower.cluster ? (this.data.clusterNames[flower.cluster] || flower.cluster) : "—"

    let html = `<strong style="font-size:13px">${this.monthLabel(flower.month)}</strong>`
    html += `<div style="color:${color}; font-size:11px; margin-top:2px; font-weight:600">${clusterName}</div>`
    html += `<div style="margin-top:6px; display:grid; grid-template-columns:auto auto; gap:1px 14px">`
    for (const [key, val] of Object.entries(dims)) {
      html += `<span style="color:#888">${key}</span><strong>${val.toFixed(1)}</strong>`
    }
    html += `</div>`
    html += `<div style="margin-top:4px; color:#666; font-size:10px">${flower.count} ${flower.count === 1 ? "entry" : "entries"}</div>`

    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 200) + "px")
      .style("opacity", 1)
  },

  monthLabel(month) {
    const [year, m] = month.split("-")
    return `${MONTH_NAMES[parseInt(m, 10) - 1]} ${year}`
  },

  hideTooltip() {
    if (this.tooltip) this.tooltip.style("opacity", 0)
  },

  destroyed() {
    if (this.tooltip) this.tooltip.remove()
  }
}
