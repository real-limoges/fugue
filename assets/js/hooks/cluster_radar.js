import * as d3 from "d3"

/** Per-cluster radar charts showing normalized dimension centroids. */
export const ClusterRadar = {
  mounted() {
    this.data = { centroids: [], clusterColors: {}, dimensions: [] }

    this.handleEvent("update-radar", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { centroids, clusterColors, dimensions } = this.data
    if (!centroids || centroids.length === 0 || !dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""

    const n = centroids.length
    // Adaptive sizing: shrink radars as k grows
    const SIZE = n <= 3 ? 210 : n <= 5 ? 170 : 140
    const RADIUS = SIZE / 2 - 40
    const CENTER = SIZE / 2

    // Responsive columns: aim for 3 per row, flex to fit
    const colPercent = n <= 3 ? (100 / n) : n <= 6 ? 33.333 : 25

    const numDims = dimensions.length
    const angleSlice = (Math.PI * 2) / numDims

    const container = d3.select(this.el)
      .style("display", "flex")
      .style("flex-wrap", "wrap")
      .style("gap", "6px")
      .style("justify-content", "center")

    const hook = this

    centroids.forEach((centroid) => {
      const color = clusterColors[centroid.id] || "#666"
      const values = dimensions.map(d => centroid.values[d] || 0)

      const wrapper = container.append("div")
        .attr("class", "radar-cell")
        .attr("data-cluster", centroid.id)
        .style("text-align", "center")
        .style("flex", `0 0 calc(${colPercent}% - 8px)`)
        .style("max-width", `calc(${colPercent}% - 8px)`)
        .style("cursor", "pointer")
        .on("click", () => {
          hook.pushEvent("cluster_selected", { cluster: centroid.id })
        })

      const svg = wrapper.append("svg")
        .attr("viewBox", `0 0 ${SIZE} ${SIZE}`)
        .attr("preserveAspectRatio", "xMidYMid meet")
        .style("width", "100%")
        .style("max-width", `${SIZE}px`)

      const g = svg.append("g")
        .attr("transform", `translate(${CENTER},${CENTER})`)

      // Grid rings
      const levels = 4
      for (let lvl = 1; lvl <= levels; lvl++) {
        const r = (RADIUS / levels) * lvl
        g.append("circle")
          .attr("r", r)
          .attr("fill", "none")
          .attr("stroke", "rgba(255,255,255,0.06)")
          .attr("stroke-width", 0.5)
      }

      // Axis lines + labels
      dimensions.forEach((dim, i) => {
        const angle = angleSlice * i - Math.PI / 2
        const x2 = Math.cos(angle) * RADIUS
        const y2 = Math.sin(angle) * RADIUS

        g.append("line")
          .attr("x1", 0).attr("y1", 0)
          .attr("x2", x2).attr("y2", y2)
          .attr("stroke", "rgba(255,255,255,0.08)")
          .attr("stroke-width", 0.5)

        const labelR = RADIUS + 16
        g.append("text")
          .attr("x", Math.cos(angle) * labelR)
          .attr("y", Math.sin(angle) * labelR)
          .attr("text-anchor", "middle")
          .attr("dominant-baseline", "middle")
          .attr("fill", "#666")
          .attr("font-size", n > 5 ? "7px" : "9px")
          .text(dim)
      })

      // Data polygon
      const points = values.map((v, i) => {
        const angle = angleSlice * i - Math.PI / 2
        const r = v * RADIUS
        return [Math.cos(angle) * r, Math.sin(angle) * r]
      })

      const lineGen = d3.lineRadial()
        .angle((_, i) => angleSlice * i)
        .radius(d => d * RADIUS)
        .curve(d3.curveLinearClosed)

      g.append("path")
        .datum(values)
        .attr("d", lineGen)
        .attr("fill", color)
        .attr("fill-opacity", 0.15)
        .attr("stroke", color)
        .attr("stroke-width", 1.5)

      // Data dots
      points.forEach(([px, py]) => {
        g.append("circle")
          .attr("cx", px).attr("cy", py)
          .attr("r", 2.5)
          .attr("fill", color)
      })

      // Cluster name below
      wrapper.append("div")
        .style("color", color)
        .style("font-size", n > 5 ? "10px" : "11px")
        .style("font-weight", "600")
        .style("margin-top", "2px")
        .style("white-space", "nowrap")
        .style("overflow", "hidden")
        .style("text-overflow", "ellipsis")
        .attr("title", centroid.name)
        .text(centroid.name)
    })
  },

  isolate(cluster) {
    d3.select(this.el).selectAll(".radar-cell").each(function() {
      const id = d3.select(this).attr("data-cluster")
      if (!cluster) {
        d3.select(this).style("opacity", 1)
      } else {
        d3.select(this).style("opacity", id === cluster ? 1 : 0.2)
      }
    })
  }
}
