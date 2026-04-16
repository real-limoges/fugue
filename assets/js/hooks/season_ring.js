import * as d3 from "d3"

/** Polar stacked chart — cluster dominance by month-of-year, pooled across all years. */
const MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const SIZE = 420
const CENTER = SIZE / 2
const OUTER_R = 155
const INNER_R = 35
const LABEL_R = OUTER_R + 18

export const SeasonRing = {
  mounted() {
    this.data = null

    this.handleEvent("update-seasonality", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { months, clusterColors, clusterNames, clusterIds } = this.data
    if (!months || months.length === 0) return

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    this.tooltip = d3.select(this.el)
      .append("div")
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

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${SIZE} ${SIZE}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("max-width", "420px")
      .style("margin", "0 auto")
      .style("display", "block")

    this.svg = svg

    const g = svg.append("g")
      .attr("transform", `translate(${CENTER},${CENTER})`)

    const angle = d3.scaleBand()
      .domain(d3.range(12))
      .range([0, 2 * Math.PI])
      .padding(0.06)

    const radius = d3.scaleLinear()
      .domain([0, 1])
      .range([INNER_R, OUTER_R])

    // Reference circles
    ;[0.25, 0.5, 0.75].forEach(t => {
      g.append("circle")
        .attr("r", radius(t))
        .attr("fill", "none")
        .attr("stroke", "rgba(255,255,255,0.04)")
        .attr("stroke-width", 0.5)
    })

    g.append("circle")
      .attr("r", INNER_R)
      .attr("fill", "none")
      .attr("stroke", "rgba(255,255,255,0.08)")
      .attr("stroke-width", 0.5)

    const hook = this

    months.forEach((m, mi) => {
      const startAngle = angle(mi)
      const endAngle = startAngle + angle.bandwidth()

      if (m.total === 0) {
        const arc = d3.arc()
          .innerRadius(INNER_R)
          .outerRadius(OUTER_R)
          .startAngle(startAngle)
          .endAngle(endAngle)

        g.append("path")
          .attr("d", arc())
          .attr("fill", "none")
          .attr("stroke", "rgba(255,255,255,0.05)")
          .attr("stroke-width", 0.5)
          .attr("stroke-dasharray", "2,2")
        return
      }

      const monthG = g.append("g").attr("class", "month-group")

      let cumulative = 0

      clusterIds.forEach(cid => {
        const count = (m.counts || {})[cid] || 0
        const proportion = count / m.total
        if (proportion <= 0) return

        const arc = d3.arc()
          .innerRadius(radius(cumulative))
          .outerRadius(radius(cumulative + proportion))
          .startAngle(startAngle)
          .endAngle(endAngle)
          .padAngle(0.01)
          .padRadius(INNER_R)

        monthG.append("path")
          .attr("class", "season-arc")
          .attr("data-cluster", cid)
          .attr("d", arc())
          .attr("fill", clusterColors[cid] || "#666")
          .attr("fill-opacity", 0.7)
          .attr("stroke", clusterColors[cid] || "#666")
          .attr("stroke-width", 0.5)
          .attr("stroke-opacity", 0.3)

        cumulative += proportion
      })

      // Invisible hit area
      const hitArc = d3.arc()
        .innerRadius(INNER_R)
        .outerRadius(OUTER_R)
        .startAngle(startAngle)
        .endAngle(endAngle)

      monthG.append("path")
        .attr("d", hitArc())
        .attr("fill", "transparent")
        .style("cursor", "default")
        .on("mouseenter", function(event) {
          hook.showTooltip(event, m, mi, clusterIds, clusterColors, clusterNames)
        })
        .on("mousemove", function(event) {
          hook.moveTooltip(event)
        })
        .on("mouseleave", function() {
          hook.hideTooltip()
        })
    })

    // Month labels
    months.forEach((_, mi) => {
      const a = angle(mi) + angle.bandwidth() / 2
      const x = LABEL_R * Math.sin(a)
      const y = -LABEL_R * Math.cos(a)

      g.append("text")
        .attr("x", x)
        .attr("y", y)
        .attr("text-anchor", "middle")
        .attr("dominant-baseline", "central")
        .attr("fill", "#666")
        .attr("font-size", "10px")
        .attr("font-weight", "600")
        .text(MONTH_LABELS[mi])
    })
  },

  showTooltip(event, month, mi, clusterIds, clusterColors, clusterNames) {
    let html = `<strong style="font-size:13px">${MONTH_LABELS[mi]}</strong>`
    html += `<div style="color:#666; font-size:10px; margin-bottom:6px">${month.total} days across all years</div>`

    const sorted = clusterIds
      .map(cid => ({
        id: cid,
        count: (month.counts || {})[cid] || 0,
        name: (clusterNames || {})[cid] || cid,
        color: clusterColors[cid] || "#888"
      }))
      .filter(d => d.count > 0)
      .sort((a, b) => b.count - a.count)

    html += `<div style="display:grid; grid-template-columns:auto auto auto; gap:1px 10px">`
    sorted.forEach(d => {
      const pct = Math.round(d.count / month.total * 100)
      html += `<span style="display:inline-flex; align-items:center; gap:3px"><span style="width:6px;height:6px;border-radius:50%;background:${d.color};display:inline-block"></span>${d.name}</span>`
      html += `<span style="color:#888; text-align:right">${d.count}d</span>`
      html += `<strong>${pct}%</strong>`
    })
    html += `</div>`

    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 200) + "px")
      .style("opacity", 1)
  },

  moveTooltip(event) {
    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 200) + "px")
  },

  hideTooltip() {
    if (this.tooltip) this.tooltip.style("opacity", 0)
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll(".season-arc")
      .attr("fill-opacity", function() {
        if (!cluster) return 0.7
        return d3.select(this).attr("data-cluster") === cluster ? 0.85 : 0.08
      })
      .attr("stroke-opacity", function() {
        if (!cluster) return 0.3
        return d3.select(this).attr("data-cluster") === cluster ? 0.6 : 0.05
      })
  },

  destroyed() {
    if (this.tooltip) this.tooltip.remove()
  }
}
