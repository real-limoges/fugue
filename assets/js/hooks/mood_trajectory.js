import * as d3 from "d3"

/** PCA projection of daily mood dimensions to 2D — one scribble for the whole run. */
export const MoodTrajectory = {
  mounted() {
    this.data = { points: [], clusterColors: {}, clusterNames: {} }

    this.handleEvent("update-trajectory", (data) => {
      this.data = data
      this.render()
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

    const xExt = d3.extent(points, p => p.x)
    const yExt = d3.extent(points, p => p.y)
    const xPad = (xExt[1] - xExt[0]) * 0.05 || 1
    const yPad = (yExt[1] - yExt[0]) * 0.05 || 1

    const dataW = (xExt[1] - xExt[0]) + 2 * xPad
    const dataH = (yExt[1] - yExt[0]) + 2 * yPad
    const scale = Math.min(innerW / dataW, innerH / dataH)
    const xMid = (xExt[0] + xExt[1]) / 2
    const yMid = (yExt[0] + yExt[1]) / 2

    const x = d3.scaleLinear()
      .domain([xMid - dataW / 2, xMid + dataW / 2])
      .range([(innerW - dataW * scale) / 2, (innerW + dataW * scale) / 2])

    const y = d3.scaleLinear()
      .domain([yMid - dataH / 2, yMid + dataH / 2])
      .range([(innerH + dataH * scale) / 2, (innerH - dataH * scale) / 2])

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

    const clipId = `traj-reveal-${Math.random().toString(36).slice(2, 8)}`
    const clipRect = defs.append("clipPath")
      .attr("id", clipId)
      .append("rect")
      .attr("x", 0).attr("y", -4)
      .attr("width", 0)
      .attr("height", innerH + 8)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left}, ${margin.top})`)
      .attr("clip-path", `url(#${clipId})`)

    const segments = []
    for (let i = 1; i < points.length; i++) {
      segments.push([points[i - 1], points[i]])
    }

    g.append("g")
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

    clipRect
      .transition()
      .duration(2800)
      .ease(d3.easeCubicOut)
      .attr("width", innerW)

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

    g.append("g")
      .selectAll("circle")
      .data(points)
      .join("circle")
      .attr("cx", d => x(d.x))
      .attr("cy", d => y(d.y))
      .attr("r", 2.2)
      .attr("fill", d => (d.cluster && clusterColors[d.cluster]) || "#888")
      .attr("fill-opacity", 0.85)
      .attr("filter", "url(#traj-glow)")
      .style("cursor", "crosshair")
      .on("mouseenter", function(event, d) { hook.showTooltip(event, d) })
      .on("mouseleave", function() { hook.hideTooltip() })
  },

  showTooltip(event, d) {
    const name = (d.cluster && this.data.clusterNames[d.cluster]) || "—"
    const color = (d.cluster && this.data.clusterColors[d.cluster]) || "#888"
    const html = `<strong>${d.date}</strong><div style="color:${color}">${name}</div>`
    const rect = this.el.getBoundingClientRect()
    this.tooltip
      .html(html)
      .style("top", (event.clientY - rect.top + 12) + "px")
      .style("left", Math.min(event.clientX - rect.left + 12, rect.width - 160) + "px")
      .style("opacity", 1)
  },

  hideTooltip() {
    if (this.tooltip) this.tooltip.style("opacity", 0)
  }
}
