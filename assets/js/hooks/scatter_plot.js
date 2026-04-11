import * as d3 from "d3"

/** Scatter plot with lasso selection, colored by dominant cluster membership. */
const MARGIN = { top: 20, right: 20, bottom: 40, left: 50 }
const WIDTH = 500
const HEIGHT = 400
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom

export const ScatterPlot = {
  mounted() {
    this.svg = null
    this.data = { points: [], xAxis: "sleep", yAxis: "anxiety", clusterColors: {} }
    this.lasso = { active: false, points: [] }

    this.handleEvent("update-scatter", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("highlight-scatter", ({ dates }) => {
      this.highlightDates(dates)
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  topWeight(point) {
    const entries = Object.entries(point.memberships || {})
    if (entries.length === 0) return 0
    return entries.reduce((a, b) => b[1] > a[1] ? b : a)[1]
  },

  getValue(point, axis) {
    if (axis.startsWith("membership:")) {
      const cluster = axis.slice("membership:".length)
      return (point.memberships || {})[cluster] || 0
    }
    return (point.values || {})[axis] || 0
  },

  render() {
    const { points, xAxis, yAxis, clusterColors } = this.data
    if (!points || points.length === 0) return

    this.el.innerHTML = ""

    const svgEl = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("max-height", `${HEIGHT}px`)

    this.svg = svgEl

    const g = svgEl.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    // Scales
    const xVals = points.map(p => this.getValue(p, xAxis))
    const yVals = points.map(p => this.getValue(p, yAxis))

    const x = d3.scaleLinear()
      .domain(d3.extent(xVals)).nice()
      .range([0, INNER_W])

    const y = d3.scaleLinear()
      .domain(d3.extent(yVals)).nice()
      .range([INNER_H, 0])

    // Axes
    g.append("g")
      .attr("transform", `translate(0,${INNER_H})`)
      .call(d3.axisBottom(x).ticks(6))
      .selectAll("text,line,path").attr("stroke", "#666").attr("fill", "#666")

    g.append("g")
      .call(d3.axisLeft(y).ticks(6))
      .selectAll("text,line,path").attr("stroke", "#666").attr("fill", "#666")

    // Axis labels
    g.append("text")
      .attr("x", INNER_W / 2)
      .attr("y", INNER_H + 35)
      .attr("text-anchor", "middle")
      .attr("fill", "#888")
      .attr("font-size", "12px")
      .text(xAxis)

    g.append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -INNER_H / 2)
      .attr("y", -38)
      .attr("text-anchor", "middle")
      .attr("fill", "#888")
      .attr("font-size", "12px")
      .text(yAxis)

    // Dots
    const dots = g.selectAll("circle.dot")
      .data(points)
      .join("circle")
      .attr("class", "dot")
      .attr("data-date", d => d.date)
      .attr("cx", d => x(this.getValue(d, xAxis)))
      .attr("cy", d => y(this.getValue(d, yAxis)))
      .attr("r", d => 3 + 4 * Math.pow(this.topWeight(d), 2))
      .attr("fill", d => this.dotColor(d, clusterColors))
      .attr("opacity", d => 0.2 + 0.7 * this.topWeight(d))

    // Lasso overlay on top — handles both click and drag
    const lassoG = g.append("g").attr("class", "lasso-layer")
    let lassoPath = null
    let lassoPoints = []
    let dragStartPos = null

    const overlay = g.append("rect")
      .attr("width", INNER_W)
      .attr("height", INNER_H)
      .attr("fill", "transparent")
      .style("cursor", "crosshair")

    overlay.on("mousedown", (event) => {
      if (event.button !== 0) return
      event.preventDefault()
      lassoPoints = []
      const [mx, my] = d3.pointer(event, g.node())
      dragStartPos = [mx, my]
      lassoPoints.push([mx, my])
      this.lasso.active = true

      lassoPath = lassoG.append("path")
        .attr("fill", "rgba(255,255,255,0.1)")
        .attr("stroke", "#fff")
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "4,2")
    })

    overlay.on("mousemove", (event) => {
      if (!this.lasso.active) return
      const [mx, my] = d3.pointer(event, g.node())
      lassoPoints.push([mx, my])
      lassoPath.attr("d", d3.line()(lassoPoints) + "Z")
    })

    overlay.on("mouseup", (event) => {
      if (!this.lasso.active) return
      this.lasso.active = false

      const [mx, my] = d3.pointer(event, g.node())
      const dist = dragStartPos
        ? Math.hypot(mx - dragStartPos[0], my - dragStartPos[1])
        : 0

      if (lassoPath) lassoPath.remove()

      // Short drag = click — find nearest dot
      if (dist < 5) {
        const nearest = this.findNearest(points, mx, my, x, y, xAxis, yAxis)
        if (nearest) {
          this.pushEvent("day_selected", { date: nearest.date })
        } else {
          this.pushEvent("clear_highlights", {})
        }
        return
      }

      if (lassoPoints.length < 3) {
        this.pushEvent("clear_highlights", {})
        return
      }

      // Point-in-polygon test
      const selected = points.filter(p => {
        const px = x(this.getValue(p, xAxis))
        const py = y(this.getValue(p, yAxis))
        return this.pointInPolygon([px, py], lassoPoints)
      })

      if (selected.length > 0) {
        const dates = selected.map(p => p.date)
        this.pushEvent("lasso_selected", { dates })
        this.highlightDates(dates)
      } else {
        this.pushEvent("clear_highlights", {})
      }
    })
  },

  dotColor(point, clusterColors) {
    const mems = point.memberships || {}
    const entries = Object.entries(mems)
    if (entries.length === 0) return "#666"

    const [topCluster] = entries.reduce((a, b) => b[1] > a[1] ? b : a)
    return clusterColors[topCluster] || "#666"
  },

  highlightDates(dates) {
    if (!this.svg) return
    const dateSet = new Set(dates)

    this.svg.selectAll("circle.dot")
      .attr("opacity", d => {
        if (dates.length === 0) return 0.2 + 0.7 * this.topWeight(d)
        return dateSet.has(d.date) ? 1 : 0.06
      })
      .attr("r", d => {
        const base = 3 + 4 * Math.pow(this.topWeight(d), 2)
        if (dates.length === 0) return base
        return dateSet.has(d.date) ? base + 2 : 2
      })
  },

  isolate(cluster) {
    if (!this.svg) return

    if (!cluster) {
      this.svg.selectAll("circle.dot")
        .attr("opacity", d => 0.2 + 0.7 * this.topWeight(d))
        .attr("r", d => 3 + 4 * Math.pow(this.topWeight(d), 2))
      return
    }

    this.svg.selectAll("circle.dot")
      .attr("opacity", d => {
        const mem = (d.memberships || {})[cluster] || 0
        return mem >= 0.3 ? 0.3 + 0.7 * mem : 0.04
      })
      .attr("r", d => {
        const mem = (d.memberships || {})[cluster] || 0
        return mem >= 0.3 ? 3 + 5 * mem : 2
      })
  },

  findNearest(points, mx, my, xScale, yScale, xAxis, yAxis) {
    let best = null
    let bestDist = 20 // max pixel distance to count as a hit
    for (const p of points) {
      const px = xScale(this.getValue(p, xAxis))
      const py = yScale(this.getValue(p, yAxis))
      const d = Math.hypot(px - mx, py - my)
      if (d < bestDist) {
        bestDist = d
        best = p
      }
    }
    return best
  },

  pointInPolygon(point, polygon) {
    const [x, y] = point
    let inside = false
    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const [xi, yi] = polygon[i]
      const [xj, yj] = polygon[j]
      const intersect = ((yi > y) !== (yj > y)) &&
        (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
      if (intersect) inside = !inside
    }
    return inside
  }
}
