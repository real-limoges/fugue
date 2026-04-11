import * as d3 from "d3"

/** Sankey flow diagram of cluster-to-cluster transitions. */
const MARGIN = { top: 30, right: 15, bottom: 10, left: 20 }
const WIDTH = 700
const HEIGHT = 280
const INNER_W = WIDTH - MARGIN.left - MARGIN.right
const INNER_H = HEIGHT - MARGIN.top - MARGIN.bottom
const NODE_W = 14
const NODE_PAD = 6

export const TransitionSankey = {
  mounted() {
    this.data = null

    this.handleEvent("update-mood-transitions", (data) => {
      this.data = data
      this.render()
    })

    this.handleEvent("isolate-cluster", ({ cluster }) => {
      this.isolate(cluster)
    })
  },

  render() {
    const { transitions, clusterIds, clusterNames, clusterColors } = this.data
    if (!transitions || transitions.length === 0 || !clusterIds || clusterIds.length === 0) return

    this.el.innerHTML = ""

    // Aggregate all transitions into from→to counts
    const flowCounts = {}
    transitions.forEach(t => {
      const key = `${t.from}->${t.to}`
      flowCounts[key] = (flowCounts[key] || 0) + 1
    })

    // Build nodes: left = "from" clusters, right = "to" clusters
    const activeFrom = new Set(transitions.map(t => t.from))
    const activeTo = new Set(transitions.map(t => t.to))
    const activeIds = clusterIds.filter(id => activeFrom.has(id) || activeTo.has(id))

    if (activeIds.length === 0) return

    // Compute node sizes (total transitions in/out)
    const fromTotals = {}
    const toTotals = {}
    Object.entries(flowCounts).forEach(([key, count]) => {
      const [from, to] = key.split("->")
      fromTotals[from] = (fromTotals[from] || 0) + count
      toTotals[to] = (toTotals[to] || 0) + count
    })

    const maxTotal = Math.max(
      ...Object.values(fromTotals),
      ...Object.values(toTotals),
      1
    )

    // Layout nodes vertically
    const leftIds = activeIds.filter(id => fromTotals[id])
    const rightIds = activeIds.filter(id => toTotals[id])

    const layoutNodes = (ids, totals, xPos) => {
      const totalSize = ids.reduce((s, id) => s + (totals[id] || 0), 0)
      const availH = INNER_H - (ids.length - 1) * NODE_PAD
      let yOff = 0

      return ids.map(id => {
        const h = Math.max(((totals[id] || 0) / totalSize) * availH, 8)
        const node = { id, x: xPos, y: yOff, h }
        yOff += h + NODE_PAD
        return node
      })
    }

    const leftNodes = layoutNodes(leftIds, fromTotals, 0)
    const rightNodes = layoutNodes(rightIds, toTotals, INNER_W - NODE_W)

    const leftMap = Object.fromEntries(leftNodes.map(n => [n.id, n]))
    const rightMap = Object.fromEntries(rightNodes.map(n => [n.id, n]))

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${WIDTH} ${HEIGHT}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")

    this.svg = svg

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    // Column labels
    svg.append("text")
      .attr("x", MARGIN.left + NODE_W / 2)
      .attr("y", 14)
      .attr("text-anchor", "middle")
      .attr("fill", "#555")
      .attr("font-size", "10px")
      .text("from")

    svg.append("text")
      .attr("x", MARGIN.left + INNER_W - NODE_W / 2)
      .attr("y", 14)
      .attr("text-anchor", "middle")
      .attr("fill", "#555")
      .attr("font-size", "10px")
      .text("to")

    // Track y-offsets for stacking links within each node
    const leftYOff = Object.fromEntries(leftIds.map(id => [id, 0]))
    const rightYOff = Object.fromEntries(rightIds.map(id => [id, 0]))

    // Draw links
    const links = Object.entries(flowCounts)
      .map(([key, count]) => {
        const [from, to] = key.split("->")
        return { from, to, count }
      })
      .sort((a, b) => b.count - a.count)

    links.forEach(link => {
      const ln = leftMap[link.from]
      const rn = rightMap[link.to]
      if (!ln || !rn) return

      const fromTotal = fromTotals[link.from] || 1
      const toTotal = toTotals[link.to] || 1
      const lh = (link.count / fromTotal) * ln.h
      const rh = (link.count / toTotal) * rn.h

      const ly = ln.y + (leftYOff[link.from] || 0)
      const ry = rn.y + (rightYOff[link.to] || 0)

      leftYOff[link.from] = (leftYOff[link.from] || 0) + lh
      rightYOff[link.to] = (rightYOff[link.to] || 0) + rh

      const x0 = NODE_W
      const x1 = INNER_W - NODE_W
      const mx = (x0 + x1) / 2

      const path = `M${x0},${ly} C${mx},${ly} ${mx},${ry} ${x1},${ry} L${x1},${ry + rh} C${mx},${ry + rh} ${mx},${ly + lh} ${x0},${ly + lh} Z`

      const color = clusterColors[link.to] || "#666"

      g.append("path")
        .attr("class", "sankey-link")
        .attr("data-from", link.from)
        .attr("data-to", link.to)
        .attr("d", path)
        .attr("fill", color)
        .attr("fill-opacity", 0.25)
        .attr("stroke", color)
        .attr("stroke-width", 0.5)
        .attr("stroke-opacity", 0.15)
    })

    // Draw nodes
    const hook = this
    const drawNodes = (nodes, totals) => {
      nodes.forEach(n => {
        const color = clusterColors[n.id] || "#666"
        const name = clusterNames[n.id] || n.id

        g.append("rect")
          .attr("class", "sankey-node")
          .attr("data-cluster", n.id)
          .attr("x", n.x)
          .attr("y", n.y)
          .attr("width", NODE_W)
          .attr("height", n.h)
          .attr("rx", 2)
          .attr("fill", color)
          .attr("fill-opacity", 0.7)
          .style("cursor", "pointer")
          .on("click", () => { hook.pushEvent("cluster_selected", { cluster: n.id }) })

        // Label
        const labelX = n.x < INNER_W / 2 ? n.x + NODE_W + 5 : n.x - 5
        const anchor = n.x < INNER_W / 2 ? "start" : "end"

        g.append("text")
          .attr("class", "sankey-label")
          .attr("data-cluster", n.id)
          .attr("x", labelX)
          .attr("y", n.y + n.h / 2)
          .attr("text-anchor", anchor)
          .attr("dominant-baseline", "middle")
          .attr("fill", color)
          .attr("font-size", "9px")
          .attr("font-weight", "500")
          .style("cursor", "pointer")
          .text(name)
          .on("click", () => { hook.pushEvent("cluster_selected", { cluster: n.id }) })
      })
    }

    drawNodes(leftNodes, fromTotals)
    drawNodes(rightNodes, toTotals)
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll(".sankey-link")
      .attr("fill-opacity", function () {
        if (!cluster) return 0.25
        const from = d3.select(this).attr("data-from")
        const to = d3.select(this).attr("data-to")
        return (from === cluster || to === cluster) ? 0.4 : 0.04
      })
      .attr("stroke-opacity", function () {
        if (!cluster) return 0.15
        const from = d3.select(this).attr("data-from")
        const to = d3.select(this).attr("data-to")
        return (from === cluster || to === cluster) ? 0.3 : 0.03
      })

    this.svg.selectAll(".sankey-node")
      .attr("fill-opacity", function () {
        if (!cluster) return 0.7
        return d3.select(this).attr("data-cluster") === cluster ? 0.9 : 0.15
      })

    this.svg.selectAll(".sankey-label")
      .attr("opacity", function () {
        if (!cluster) return 1
        return d3.select(this).attr("data-cluster") === cluster ? 1 : 0.25
      })
  }
}
