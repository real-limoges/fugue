import * as d3 from "d3"

/** Pearson correlation matrix between mood dimensions. */
const CELL = 50
const MARGIN = { top: 60, right: 10, bottom: 10, left: 70 }

export const CorrelationHeatmap = {
  mounted() {
    this.data = { matrix: [], dimensions: [] }

    this.handleEvent("update-correlations", (data) => {
      this.data = data
      this.render()
    })
  },

  render() {
    const { matrix, dimensions } = this.data
    if (!matrix || matrix.length === 0 || !dimensions || dimensions.length === 0) return

    this.el.innerHTML = ""

    const n = dimensions.length
    const size = n * CELL
    const width = MARGIN.left + size + MARGIN.right
    const height = MARGIN.top + size + MARGIN.bottom

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("max-width", `${width}px`)

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    // Color scale: negative (cool) → zero (neutral) → positive (warm)
    const colorScale = d3.scaleLinear()
      .domain([-1, 0, 1])
      .range(["#42c8e6", "#1a1a2e", "#e44dbc"])

    // Cells
    for (let row = 0; row < n; row++) {
      for (let col = 0; col < n; col++) {
        const val = matrix[row][col]
        const absVal = Math.abs(val)

        g.append("rect")
          .attr("x", col * CELL)
          .attr("y", row * CELL)
          .attr("width", CELL - 2)
          .attr("height", CELL - 2)
          .attr("rx", 3)
          .attr("fill", row === col ? "rgba(255,255,255,0.03)" : colorScale(val))
          .attr("fill-opacity", row === col ? 1 : 0.15 + 0.85 * absVal)

        // Value label
        g.append("text")
          .attr("x", col * CELL + (CELL - 2) / 2)
          .attr("y", row * CELL + (CELL - 2) / 2)
          .attr("text-anchor", "middle")
          .attr("dominant-baseline", "middle")
          .attr("fill", absVal > 0.4 ? "#eee" : "#666")
          .attr("font-size", row === col ? "8px" : "11px")
          .attr("font-weight", absVal > 0.5 ? "bold" : "normal")
          .text(row === col ? "—" : val.toFixed(2))
      }
    }

    // Row labels (left)
    dimensions.forEach((dim, i) => {
      svg.append("text")
        .attr("x", MARGIN.left - 6)
        .attr("y", MARGIN.top + i * CELL + (CELL - 2) / 2)
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .attr("fill", "#888")
        .attr("font-size", "11px")
        .text(dim)
    })

    // Column labels (top, rotated)
    dimensions.forEach((dim, i) => {
      svg.append("text")
        .attr("transform", `translate(${MARGIN.left + i * CELL + (CELL - 2) / 2}, ${MARGIN.top - 8}) rotate(-45)`)
        .attr("text-anchor", "start")
        .attr("fill", "#888")
        .attr("font-size", "11px")
        .text(dim)
    })
  }
}
