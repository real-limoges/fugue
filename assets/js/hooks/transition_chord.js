import * as d3 from "d3"

/** Chord diagram showing transition volume between cluster pairs. */
const SIZE = 360
const OUTER_R = SIZE / 2 - 50
const INNER_R = OUTER_R - 12

export const TransitionChord = {
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
    const { chordMatrix, clusterIds, clusterNames, clusterColors } = this.data
    if (!chordMatrix || chordMatrix.length === 0) return

    // Check if there are any transitions at all
    const hasData = chordMatrix.some(row => row.some(v => v > 0))
    if (!hasData) return

    this.el.innerHTML = ""

    const svg = d3.select(this.el)
      .append("svg")
      .attr("viewBox", `0 0 ${SIZE} ${SIZE}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("max-width", `${SIZE}px`)

    this.svg = svg
    const hook = this

    const g = svg.append("g")
      .attr("transform", `translate(${SIZE / 2},${SIZE / 2})`)

    const chord = d3.chord()
      .padAngle(0.06)
      .sortSubgroups(d3.descending)

    const chords = chord(chordMatrix)

    const arc = d3.arc()
      .innerRadius(INNER_R)
      .outerRadius(OUTER_R)

    const ribbon = d3.ribbon()
      .radius(INNER_R)

    // Arcs (cluster segments)
    g.selectAll("path.chord-arc")
      .data(chords.groups)
      .join("path")
      .attr("class", "chord-arc")
      .attr("data-cluster", d => clusterIds[d.index])
      .attr("d", arc)
      .attr("fill", d => clusterColors[clusterIds[d.index]] || "#666")
      .attr("fill-opacity", 0.75)
      .attr("stroke", d => clusterColors[clusterIds[d.index]] || "#666")
      .attr("stroke-width", 0.5)
      .attr("stroke-opacity", 0.4)
      .style("cursor", "pointer")
      .on("click", (event, d) => {
        hook.pushEvent("cluster_selected", { cluster: clusterIds[d.index] })
      })

    // Ribbons (transitions)
    g.selectAll("path.chord-ribbon")
      .data(chords)
      .join("path")
      .attr("class", "chord-ribbon")
      .attr("data-source", d => clusterIds[d.source.index])
      .attr("data-target", d => clusterIds[d.target.index])
      .attr("d", ribbon)
      .attr("fill", d => clusterColors[clusterIds[d.target.index]] || "#666")
      .attr("fill-opacity", 0.3)
      .attr("stroke", d => clusterColors[clusterIds[d.target.index]] || "#666")
      .attr("stroke-width", 0.5)
      .attr("stroke-opacity", 0.15)

    // Labels around the outside
    g.selectAll("text.chord-label")
      .data(chords.groups)
      .join("text")
      .attr("class", "chord-label")
      .attr("data-cluster", d => clusterIds[d.index])
      .attr("transform", d => {
        const angle = (d.startAngle + d.endAngle) / 2
        const r = OUTER_R + 14
        const x = r * Math.sin(angle)
        const y = -r * Math.cos(angle)
        return `translate(${x},${y})`
      })
      .attr("text-anchor", d => {
        const angle = (d.startAngle + d.endAngle) / 2
        return angle > Math.PI ? "end" : "start"
      })
      .attr("dominant-baseline", "middle")
      .attr("fill", d => clusterColors[clusterIds[d.index]] || "#888")
      .attr("font-size", "9px")
      .attr("font-weight", "500")
      .style("cursor", "pointer")
      .text(d => clusterNames[clusterIds[d.index]] || clusterIds[d.index])
      .on("click", (event, d) => {
        hook.pushEvent("cluster_selected", { cluster: clusterIds[d.index] })
      })
  },

  isolate(cluster) {
    if (!this.svg) return

    this.svg.selectAll(".chord-arc")
      .attr("fill-opacity", function () {
        if (!cluster) return 0.75
        return d3.select(this).attr("data-cluster") === cluster ? 0.9 : 0.12
      })

    this.svg.selectAll(".chord-ribbon")
      .attr("fill-opacity", function () {
        if (!cluster) return 0.3
        const src = d3.select(this).attr("data-source")
        const tgt = d3.select(this).attr("data-target")
        return (src === cluster || tgt === cluster) ? 0.5 : 0.03
      })
      .attr("stroke-opacity", function () {
        if (!cluster) return 0.15
        const src = d3.select(this).attr("data-source")
        const tgt = d3.select(this).attr("data-target")
        return (src === cluster || tgt === cluster) ? 0.3 : 0.02
      })

    this.svg.selectAll(".chord-label")
      .attr("opacity", function () {
        if (!cluster) return 1
        return d3.select(this).attr("data-cluster") === cluster ? 1 : 0.25
      })
  }
}
