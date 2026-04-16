import * as d3 from "d3"

/** PCA projection of daily mood dimensions to 2D — one scribble for the whole run. */
export const MoodTrajectory = {
  mounted() {
    this.data = { points: [], annotations: [], clusterColors: {}, clusterNames: {} }
    this.focusDate = null

    this.handleEvent("update-trajectory", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("day-focus", ({ day }) => {
      this.focusDate = day?.date || null
      this.applyFocus()
    })

    this.handleEvent("update-trajectory-colors", ({ clusterByDate, clusterColors, clusterNames }) => {
      this.data.clusterColors = clusterColors
      this.data.clusterNames = clusterNames
      // Keep this.data.points current so resize re-renders with correct clusters
      this.data.points = this.data.points.map(p => ({ ...p, cluster: clusterByDate[p.date] ?? null }))

      const svg = d3.select(this.el).select("svg")
      if (svg.empty()) return

      // Use clusterByDate directly — bound datum still holds old cluster values
      svg.selectAll("line")
        .attr("stroke", d => {
          const cluster = clusterByDate[d[1].date] ?? null
          return (cluster && clusterColors[cluster]) || "#666"
        })

      // Mutate circle datum in-place so showTooltip sees the new cluster
      svg.selectAll("circle.dot")
        .each(function(d) { d.cluster = clusterByDate[d.date] ?? null })
        .attr("fill", d => (d.cluster && clusterColors[d.cluster]) || "#888")
    })

    this._onResize = () => this.render()
    window.addEventListener("resize", this._onResize)
  },

  destroyed() {
    window.removeEventListener("resize", this._onResize)
    if (this.tooltip) this.tooltip.remove()
  },

  render() {
    const { points, clusterColors } = this.data
    if (!points || points.length < 2) return

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    const width = this.el.clientWidth || 900
    const height = 520
    const margin = { top: 24, right: 24, bottom: 24, left: 24 }
    const innerW = width - margin.left - margin.right
    const innerH = height - margin.top - margin.bottom

    this.dims = { innerW, innerH, margin }

    const { x, y } = this.computeScales()
    this.x = x
    this.y = y

    const svg = d3.select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .style("display", "block")

    const defs = svg.append("defs")

    const glow = defs.append("filter")
      .attr("id", "traj-glow")
      .attr("x", "-50%").attr("y", "-50%")
      .attr("width", "200%").attr("height", "200%")
    glow.append("feGaussianBlur").attr("stdDeviation", "1.6").attr("result", "blur")
    const merge = glow.append("feMerge")
    merge.append("feMergeNode").attr("in", "blur")
    merge.append("feMergeNode").attr("in", "SourceGraphic")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left}, ${margin.top})`)

    const segments = []
    for (let i = 1; i < points.length; i++) {
      segments.push([points[i - 1], points[i]])
    }

    this.lines = g.append("g")
      .selectAll("line")
      .data(segments)
      .join("line")
      .attr("x1", d => x(d[0].x))
      .attr("y1", d => y(d[0].y))
      .attr("x2", d => x(d[1].x))
      .attr("y2", d => y(d[1].y))
      .attr("stroke", d => (d[1].cluster && clusterColors[d[1].cluster]) || "#666")
      .attr("stroke-opacity", 0.55)
      .attr("stroke-width", 1.25)
      .attr("stroke-linecap", "round")

    this.tooltip = d3.select(this.el)
      .append("div")
      .attr("class", "trajectory-tooltip")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "rgba(10,10,26,0.92)")
      .style("color", "#eee")
      .style("padding", "8px 12px")
      .style("border-radius", "6px")
      .style("border", "1px solid rgba(255,255,255,0.08)")
      .style("font-size", "11px")
      .style("line-height", "1.5")
      .style("white-space", "nowrap")
      .style("z-index", "100")
      .style("opacity", 0)

    const hook = this

    this.circles = g.append("g")
      .selectAll("circle.dot")
      .data(points)
      .join("circle")
      .attr("class", "dot")
      .attr("cx", d => x(d.x))
      .attr("cy", d => y(d.y))
      .attr("r", 2.2)
      .attr("fill", d => (d.cluster && clusterColors[d.cluster]) || "#888")
      .attr("fill-opacity", 0.85)
      .attr("filter", "url(#traj-glow)")
      .attr("stroke-opacity", 0)

    this.hitCircles = g.append("g")
      .selectAll("circle.hit")
      .data(points)
      .join("circle")
      .attr("class", "hit")
      .attr("cx", d => x(d.x))
      .attr("cy", d => y(d.y))
      .attr("r", 7)
      .attr("fill", "transparent")
      .style("cursor", "crosshair")
      .on("mouseenter", function(event, d) { hook.showTooltip(event, d) })
      .on("mouseleave", function() { hook.hideTooltip() })
      .on("click", function(event, d) { hook.pushEvent("day_selected", { date: d.date }) })

    this.renderAnnotations(g, x, y)

    this.applyFocus()
  },

  /**
   * Personal milestones overlaid on the trajectory. Each annotation is
   * authored as `{date, label, note?}` in `Fugue.MoodLive.Annotations`. We
   * resolve each date to a projected (x, y), drop a small ring marker, and
   * place the label with a leader line. Layout is intentionally simple:
   * labels alternate above/below the point so successive annotations don't
   * collide horizontally. Tweak the file, refresh, see it move.
   *
   * Markers are interactive: hovering shows a tooltip with the label, date,
   * cluster, and optional note. Clicking selects the day (same as clicking
   * any trajectory point), so the calendar and day-detail panels react.
   */
  renderAnnotations(g, x, y) {
    const { points, annotations } = this.data
    if (!annotations || annotations.length === 0) return

    const byDate = new Map(points.map(p => [p.date, p]))

    const resolved = annotations
      .map((a, i) => {
        const point = byDate.get(a.date)
        if (!point) {
          console.warn(`[trajectory] annotation date not in dataset: ${a.date}`)
          return null
        }
        return { ...a, point, idx: i }
      })
      .filter(Boolean)
      .sort((a, b) => a.date < b.date ? -1 : 1)

    if (resolved.length === 0) return

    const hook = this
    const layer = g.append("g").attr("class", "trajectory-annotations")
    const labels = layer.append("g").attr("pointer-events", "none")
    const markers = layer.append("g")

    resolved.forEach((a, i) => {
      const px = x(a.point.x)
      const py = y(a.point.y)
      // Alternate above/below so adjacent labels stagger vertically.
      const above = i % 2 === 0
      const dy = above ? -28 : 28
      const dx = 14
      const lx = px + dx
      const ly = py + dy

      labels.append("line")
        .attr("x1", px).attr("y1", py)
        .attr("x2", lx).attr("y2", ly)
        .attr("stroke", "rgba(255,255,255,0.45)")
        .attr("stroke-width", 0.75)

      const text = labels.append("text")
        .attr("x", lx + 4)
        .attr("y", ly)
        .attr("text-anchor", "start")
        .attr("dominant-baseline", "middle")
        .attr("fill", "rgba(255,255,255,0.92)")
        .attr("font-size", "10.5px")
        .attr("font-family", "ui-serif, Georgia, serif")
        .attr("font-style", "italic")
        .text(a.label)

      // Dark halo behind the label for legibility against any cluster color.
      const bbox = text.node().getBBox()
      labels.insert("rect", "text:last-child")
        .attr("x", bbox.x - 3)
        .attr("y", bbox.y - 1)
        .attr("width", bbox.width + 6)
        .attr("height", bbox.height + 2)
        .attr("fill", "rgba(10,10,26,0.55)")
        .attr("rx", 2)

      markers.append("circle")
        .attr("cx", px).attr("cy", py)
        .attr("r", 4)
        .attr("fill", "none")
        .attr("stroke", "#fff")
        .attr("stroke-width", 1.25)
        .attr("stroke-opacity", 0.9)
        .attr("pointer-events", "none")

      // Generous transparent hit target. Sits above the day-level hit circles
      // so an annotated day's hover surfaces the milestone instead of the
      // generic cluster tooltip — that's almost always what the reader wants.
      markers.append("circle")
        .attr("cx", px).attr("cy", py)
        .attr("r", 10)
        .attr("fill", "transparent")
        .style("cursor", "pointer")
        .on("mouseenter", function(event) { hook.showAnnotationTooltip(event, a) })
        .on("mouseleave", function() { hook.hideTooltip() })
        .on("click", function() { hook.pushEvent("day_selected", { date: a.date }) })
    })
  },

  showAnnotationTooltip(event, a) {
    const cluster = a.point.cluster
    const clusterName = (cluster && this.data.clusterNames[cluster]) || null
    const color = (cluster && this.data.clusterColors[cluster]) || "#888"
    const noteHtml = a.note
      ? `<div style="margin-top:4px;color:#ddd;white-space:normal;max-width:240px">${a.note}</div>`
      : ""
    const clusterHtml = clusterName
      ? `<div style="margin-top:4px;color:${color}">${clusterName}</div>`
      : ""
    const html = `
      <div style="font-style:italic;font-family:ui-serif,Georgia,serif;font-size:12px">${a.label}</div>
      <div style="color:#888;font-size:10px;margin-top:1px">${a.date}</div>
      ${noteHtml}
      ${clusterHtml}
    `
    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("white-space", a.note ? "normal" : "nowrap")
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 260) + "px")
      .style("opacity", 1)
  },

  computeScales() {
    const { points } = this.data
    const { innerW, innerH } = this.dims

    const xExt = d3.extent(points, p => p.x)
    const yExt = d3.extent(points, p => p.y)
    const xPad = (xExt[1] - xExt[0]) * 0.08 || 1
    const yPad = (yExt[1] - yExt[0]) * 0.08 || 1

    const dataW = (xExt[1] - xExt[0]) + 2 * xPad
    const dataH = (yExt[1] - yExt[0]) + 2 * yPad
    const fit = Math.min(innerW / dataW, innerH / dataH)
    const xMid = (xExt[0] + xExt[1]) / 2
    const yMid = (yExt[0] + yExt[1]) / 2

    const x = d3.scaleLinear()
      .domain([xMid - dataW / 2, xMid + dataW / 2])
      .range([(innerW - dataW * fit) / 2, (innerW + dataW * fit) / 2])

    const y = d3.scaleLinear()
      .domain([yMid - dataH / 2, yMid + dataH / 2])
      .range([(innerH + dataH * fit) / 2, (innerH - dataH * fit) / 2])

    return { x, y }
  },

  applyFocus() {
    if (!this.circles) return
    const target = this.focusDate

    if (!target) {
      this.circles.interrupt()
        .transition().duration(220)
        .attr("r", 2.2)
        .attr("stroke", "none")
        .attr("stroke-width", 0)
        .attr("stroke-opacity", 0)
      return
    }

    this.circles.filter(d => d.date !== target)
      .interrupt()
      .transition().duration(220)
      .attr("r", 2.2)
      .attr("stroke", "none")
      .attr("stroke-width", 0)
      .attr("stroke-opacity", 0)

    this.circles.filter(d => d.date === target)
      .interrupt()
      .attr("r", 9)
      .attr("stroke", "#fff")
      .attr("stroke-width", 2)
      .attr("stroke-opacity", 1)
      .transition().duration(900).ease(d3.easeCubicOut)
      .attr("r", 5)
      .attr("stroke-width", 1.25)
      .attr("stroke-opacity", 0.9)
  },

  showTooltip(event, d) {
    const name = (d.cluster && this.data.clusterNames[d.cluster]) || "—"
    const color = (d.cluster && this.data.clusterColors[d.cluster]) || "#888"
    const html = `<strong>${d.date}</strong><div style="color:${color}">${name}</div>`
    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("white-space", "nowrap")
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 160) + "px")
      .style("opacity", 1)
  },

  hideTooltip() {
    if (this.tooltip) this.tooltip.style("opacity", 0)
  }
}
