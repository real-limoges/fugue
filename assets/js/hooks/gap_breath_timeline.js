import * as d3 from "d3"

const HEIGHT = 170
const MARGIN = { top: 18, right: 14, bottom: 22, left: 14 }
const MIN_BLOB_WIDTH = 4
const MAX_HALF_HEIGHT = 46
const MIN_HALF_HEIGHT = 1.2
const BASELINE_COLOR = "rgba(255,255,255,0.08)"

export const GapBreathTimeline = {
  mounted() {
    this.data = null

    this.handleEvent("update-gaps", (data) => {
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
    if (!this.data) return
    const { transitions, imputedMemberships, dateRange, clusterColors, clusterNames } = this.data
    if (!dateRange || !transitions) return

    this.el.innerHTML = ""
    this.el.style.position = "relative"

    const width = this.el.clientWidth || 900
    const innerW = width - MARGIN.left - MARGIN.right
    const innerH = HEIGHT - MARGIN.top - MARGIN.bottom
    const midY = innerH / 2

    const t0 = parseDate(dateRange.start)
    const t1 = parseDate(dateRange.end)
    const x = d3.scaleTime().domain([t0, t1]).range([0, innerW])

    const svg = d3.select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", HEIGHT)
      .style("display", "block")

    const g = svg.append("g")
      .attr("transform", `translate(${MARGIN.left},${MARGIN.top})`)

    g.append("line")
      .attr("x1", 0).attr("x2", innerW)
      .attr("y1", midY).attr("y2", midY)
      .attr("stroke", BASELINE_COLOR)
      .attr("stroke-width", 1)

    const axis = d3.axisBottom(x)
      .ticks(d3.timeYear.every(1))
      .tickFormat(d3.timeFormat("%Y"))
      .tickSize(0)
      .tickPadding(8)

    g.append("g")
      .attr("transform", `translate(0,${innerH + 2})`)
      .call(axis)
      .call(sel => sel.select(".domain").remove())
      .call(sel => sel.selectAll("text")
        .attr("fill", "#666")
        .attr("font-size", "10px"))

    const blobs = transitions
      .map(t => buildBlob(t, imputedMemberships, clusterColors, clusterNames || {}))
      .filter(Boolean)

    if (blobs.length === 0) {
      g.append("text")
        .attr("x", innerW / 2)
        .attr("y", midY)
        .attr("text-anchor", "middle")
        .attr("fill", "#666")
        .attr("font-size", "11px")
        .text("no gaps in range")
      return
    }

    const hook = this
    const area = d3.area()
      .curve(d3.curveCatmullRom.alpha(0.5))
      .x(d => x(d.date))
      .y0(d => midY - d.half)
      .y1(d => midY + d.half)

    g.append("g")
      .selectAll("path.breath")
      .data(blobs)
      .join("path")
      .attr("class", "breath")
      .attr("d", d => {
        const widthPx = x(d.endDate) - x(d.startDate)
        if (d.samples.length >= 2 && widthPx >= MIN_BLOB_WIDTH) {
          return area(d.samples)
        }
        const cx = x(d.startDate)
        const r = Math.max(MIN_BLOB_WIDTH / 2, widthPx / 2)
        return `M ${cx - r} ${midY - d.peakHalf} L ${cx + r} ${midY - d.peakHalf} L ${cx + r} ${midY + d.peakHalf} L ${cx - r} ${midY + d.peakHalf} Z`
      })
      .attr("fill", d => d.color)
      .attr("fill-opacity", 0.72)
      .attr("stroke", d => d.color)
      .attr("stroke-opacity", 0.9)
      .attr("stroke-width", 0.6)
      .style("cursor", "pointer")
      .on("mouseenter", function(event, d) {
        d3.select(this).attr("fill-opacity", 1)
        hook.showTooltip(event, d)
      })
      .on("mousemove", function(event, d) { hook.moveTooltip(event) })
      .on("mouseleave", function() {
        d3.select(this).attr("fill-opacity", 0.72)
        hook.hideTooltip()
      })
      .on("click", function(event, d) {
        hook.pushEvent("gap_selected", { start: d.startStr, length: d.length })
      })

    this.tooltip = d3.select(this.el)
      .append("div")
      .attr("class", "breath-tooltip")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "rgba(10,10,26,0.94)")
      .style("color", "#eee")
      .style("padding", "8px 12px")
      .style("border-radius", "6px")
      .style("border", "1px solid rgba(255,255,255,0.08)")
      .style("font-size", "11px")
      .style("line-height", "1.5")
      .style("white-space", "nowrap")
      .style("z-index", "100")
      .style("opacity", 0)
  },

  showTooltip(event, d) {
    const plural = d.length === 1 ? "day" : "days"
    const html = `
      <strong>${d.startStr}</strong> · ${d.length} ${plural}
      <div style="color:${d.color}">${d.clusterName}</div>
    `
    this.tooltip.html(html).style("opacity", 1)
    this.moveTooltip(event)
  },

  moveTooltip(event) {
    const rect = this.el.getBoundingClientRect()
    const top = event.clientY - rect.top + 14
    const left = Math.min(event.clientX - rect.left + 14, rect.width - 180)
    this.tooltip.style("top", top + "px").style("left", left + "px")
  },

  hideTooltip() {
    if (this.tooltip) this.tooltip.style("opacity", 0)
  }
}

function parseDate(str) {
  return d3.timeParse("%Y-%m-%d")(str)
}

function addDays(date, n) {
  const d = new Date(date)
  d.setDate(d.getDate() + n)
  return d
}

function fmtDate(date) {
  return d3.timeFormat("%Y-%m-%d")(date)
}

function buildBlob(transition, imputed, clusterColors, clusterNames) {
  const gap = transition.gap || {}
  const startStr = gap.start
  const length = gap.length
  if (!startStr || !length) return null

  const startDate = parseDate(startStr)
  if (!startDate) return null

  const totals = {}
  const samples = []
  let peakHalf = MIN_HALF_HEIGHT

  for (let i = 0; i < length; i++) {
    const day = addDays(startDate, i)
    const key = fmtDate(day)
    const mems = (imputed && imputed[key]) || transition.before || {}
    const { cluster, strength } = dominantOf(mems)
    if (cluster) totals[cluster] = (totals[cluster] || 0) + strength
    const half = Math.max(MIN_HALF_HEIGHT, strength * MAX_HALF_HEIGHT)
    if (half > peakHalf) peakHalf = half
    samples.push({ date: day, half, strength, cluster })
  }

  const dominantCluster = Object.entries(totals)
    .sort((a, b) => b[1] - a[1])[0]?.[0]
  const color = (dominantCluster && clusterColors[dominantCluster]) || "#888"
  const clusterName = (dominantCluster && clusterNames[dominantCluster]) || dominantCluster || "—"

  const endDate = addDays(startDate, Math.max(length - 1, 0))

  return {
    startStr,
    startDate,
    endDate,
    length,
    samples,
    peakHalf,
    color,
    clusterName,
  }
}

function dominantOf(mems) {
  if (!mems) return { cluster: null, strength: 0 }
  let bestK = null
  let bestV = 0
  for (const k in mems) {
    const v = mems[k]
    if (typeof v === "number" && v > bestV) {
      bestV = v
      bestK = k
    }
  }
  return { cluster: bestK, strength: bestV }
}
