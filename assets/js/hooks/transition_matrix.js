import * as d3 from "d3"

/** Row-normalized transition matrix (before-gap vs after-gap clusters). */
const CELL = 46
const MARGIN = { top: 70, right: 10, bottom: 10, left: 100 }

export const TransitionMatrix = {
  mounted() {
    this.data = null

    this.handleEvent("update-transition-matrix", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { matrix, clusterIds, clusterNames, clusterColors } = this.data
    if (!matrix || matrix.length === 0) return

    this.el.innerHTML = ""

    const n = clusterIds.length
    const size = n * CELL
    const width = MARGIN.left + size + MARGIN.right
    const height = MARGIN.top + size + MARGIN.bottom

    // Row-normalize: each row sums to 1 (proportion of transitions from that cluster)
    const normed = matrix.map(row => {
      const total = row.reduce((s, v) => s + v, 0)
      return total > 0 ? row.map(v => v / total) : row.map(() => 0)
    })

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("max-width", `${width}px`)

    this.svg = svg

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    // Axis labels
    svg.append("text")
      .attr("transform", `translate(14, ${MARGIN.top + size / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", "#555")
      .attr("font-size", "10px")
      .text("before gap")

    svg.append("text")
      .attr("x", MARGIN.left + size / 2)
      .attr("y", 14)
      .attr("text-anchor", "middle")
      .attr("fill", "#555")
      .attr("font-size", "10px")
      .text("after gap")

    // Cells
    for (let row = 0; row < n; row++) {
      for (let col = 0; col < n; col++) {
        const val = normed[row][col]
        const rawCount = matrix[row][col]
        const toColor = clusterColors[clusterIds[col]] || "#666"

        if (row === col) {
          g.append("rect")
            .attr("class", "matrix-cell")
            .attr("data-from", clusterIds[row])
            .attr("data-to", clusterIds[col])
            .attr("x", col * CELL)
            .attr("y", row * CELL)
            .attr("width", CELL - 2)
            .attr("height", CELL - 2)
            .attr("rx", 3)
            .attr("fill", "rgba(255,255,255,0.02)")

          g.append("text")
            .attr("class", "matrix-label")
            .attr("data-from", clusterIds[row])
            .attr("data-to", clusterIds[col])
            .attr("x", col * CELL + (CELL - 2) / 2)
            .attr("y", row * CELL + (CELL - 2) / 2)
            .attr("text-anchor", "middle")
            .attr("dominant-baseline", "middle")
            .attr("fill", "#333")
            .attr("font-size", "9px")
            .text("—")
          continue
        }

        g.append("rect")
          .attr("class", "matrix-cell")
          .attr("data-from", clusterIds[row])
          .attr("data-to", clusterIds[col])
          .attr("x", col * CELL)
          .attr("y", row * CELL)
          .attr("width", CELL - 2)
          .attr("height", CELL - 2)
          .attr("rx", 3)
          .attr("fill", toColor)
          .attr("fill-opacity", val > 0 ? 0.1 + 0.7 * val : 0.03)

        if (rawCount > 0) {
          g.append("text")
            .attr("class", "matrix-label")
            .attr("data-from", clusterIds[row])
            .attr("data-to", clusterIds[col])
            .attr("x", col * CELL + (CELL - 2) / 2)
            .attr("y", row * CELL + (CELL - 2) / 2 - 4)
            .attr("text-anchor", "middle")
            .attr("dominant-baseline", "middle")
            .attr("fill", val > 0.35 ? "#eee" : "#888")
            .attr("font-size", "12px")
            .attr("font-weight", val > 0.4 ? "bold" : "normal")
            .text((val * 100).toFixed(0) + "%")

          // Raw count underneath
          g.append("text")
            .attr("class", "matrix-label")
            .attr("data-from", clusterIds[row])
            .attr("data-to", clusterIds[col])
            .attr("x", col * CELL + (CELL - 2) / 2)
            .attr("y", row * CELL + (CELL - 2) / 2 + 9)
            .attr("text-anchor", "middle")
            .attr("dominant-baseline", "middle")
            .attr("fill", "#555")
            .attr("font-size", "8px")
            .text(`n=${rawCount}`)
        }
      }
    }

    // Row labels (left — "from" clusters)
    clusterNames.forEach((name, i) => {
      const color = clusterColors[clusterIds[i]] || "#888"
      svg.append("text")
        .attr("class", "matrix-row-label")
        .attr("data-cluster", clusterIds[i])
        .attr("x", MARGIN.left - 6)
        .attr("y", MARGIN.top + i * CELL + (CELL - 2) / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", color)
        .attr("font-size", "10px")
        .text(name.length > 16 ? name.slice(0, 15) + "…" : name)
    })

    // Column labels (top — "to" clusters, rotated)
    clusterNames.forEach((name, i) => {
      const color = clusterColors[clusterIds[i]] || "#888"
      svg.append("text")
        .attr("class", "matrix-col-label")
        .attr("data-cluster", clusterIds[i])
        .attr("transform", `translate(${MARGIN.left + i * CELL + (CELL - 2) / 2}, ${MARGIN.top - 8}) rotate(-45)`)
        .attr("text-anchor", "start")
        .attr("fill", color)
        .attr("font-size", "10px")
        .text(name.length > 16 ? name.slice(0, 15) + "…" : name)
    })
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll(".matrix-cell")
      .attr("opacity", function () {
        if (!cluster) return 1
        const from = d3.select(this).attr("data-from")
        const to = d3.select(this).attr("data-to")
        return (from === cluster || to === cluster) ? 1 : 0.15
      })

    this.svg.selectAll(".matrix-label")
      .attr("opacity", function () {
        if (!cluster) return 1
        const from = d3.select(this).attr("data-from")
        const to = d3.select(this).attr("data-to")
        return (from === cluster || to === cluster) ? 1 : 0.15
      })

    this.svg.selectAll(".matrix-row-label, .matrix-col-label")
      .attr("opacity", function () {
        if (!cluster) return 1
        return d3.select(this).attr("data-cluster") === cluster ? 1 : 0.3
      })
  }
}
