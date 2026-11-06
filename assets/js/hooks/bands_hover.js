// @ts-check
/** Crosshair + hover tooltip for the temperature-bands page. All rendering
 *  and data prep is server-side; this hook only positions the crosshair and
 *  tooltip based on cursor X. */

/**
 * One x-sample of the bands chart, as the server encodes it in `data-series`.
 * @typedef {object} SeriesPoint
 * @property {number} x viewBox x-coordinate, relative to the plot's left margin
 * @property {string} date
 * @property {Record<string, number>} mems membership per function name, 0..1
 */

/**
 * A membership function legend entry, from `data-mfs`.
 * @typedef {object} MembershipFn
 * @property {string} name
 * @property {string} color
 */

/**
 * @typedef {object} State
 * @property {SVGSVGElement} svg
 * @property {Element | null} crosshair
 * @property {number} innerW
 * @property {number} mLeft
 * @property {SeriesPoint[]} series
 * @property {MembershipFn[]} mfs
 * @property {HTMLDivElement} tip
 * @property {(e: MouseEvent) => void} onMove
 * @property {() => void} onLeave
 */

/**
 * @typedef {object} Methods
 * @property {(event: MouseEvent) => void} handleMove
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const BandsHover = {
  mounted() {
    const svg = this.el.querySelector("#bands-svg")
    if (!(svg instanceof SVGSVGElement)) return
    this.svg = svg

    this.crosshair = this.svg.querySelector(".bands-crosshair")
    this.innerW = parseFloat(this.svg.dataset.innerW || "")
    this.mLeft = parseFloat(this.svg.dataset.mLeft || "")
    this.series = JSON.parse(this.svg.dataset.series || "[]")
    this.mfs = JSON.parse(this.svg.dataset.mfs || "[]")

    this.tip = document.createElement("div")
    this.tip.style.cssText = `
      position: absolute; pointer-events: none;
      background: #0f172a; border: 1px solid #1f2937;
      border-radius: 6px; padding: 8px 10px;
      font-family: ui-monospace, monospace; font-size: 11px;
      color: #e5e7eb; box-shadow: 0 4px 12px rgba(0,0,0,0.4);
      opacity: 0; z-index: 20;
    `
    this.el.appendChild(this.tip)

    /** @param {MouseEvent} e */
    this.onMove = (e) => this.handleMove(e)
    this.onLeave = () => {
      if (this.crosshair) this.crosshair.setAttribute("opacity", "0")
      this.tip.style.opacity = "0"
    }

    this.svg.addEventListener("mousemove", this.onMove)
    this.svg.addEventListener("mouseleave", this.onLeave)
  },

  updated() {
    // Server re-rendered (slider change); refresh cached data.
    const svg = this.el.querySelector("#bands-svg")
    if (!(svg instanceof SVGSVGElement)) return
    this.svg = svg
    this.crosshair = this.svg.querySelector(".bands-crosshair")
    this.series = JSON.parse(this.svg.dataset.series || "[]")
    this.mfs = JSON.parse(this.svg.dataset.mfs || "[]")
  },

  handleMove(event) {
    if (!this.series.length) return
    const viewBox = this.svg.getAttribute("viewBox")
    if (!viewBox) return
    const rect = this.svg.getBoundingClientRect()
    const scaleX = rect.width / parseFloat(viewBox.split(" ")[2])
    const mx = (event.clientX - rect.left) / scaleX - this.mLeft
    if (mx < 0 || mx > this.innerW) return

    // Bisect series by x-coordinate
    let lo = 0,
      hi = this.series.length - 1
    while (lo < hi) {
      const mid = (lo + hi) >> 1
      if (this.series[mid].x < mx) lo = mid + 1
      else hi = mid
    }
    const d = this.series[lo]

    if (this.crosshair) {
      this.crosshair.setAttribute("x1", String(d.x))
      this.crosshair.setAttribute("x2", String(d.x))
      this.crosshair.setAttribute("opacity", "0.85")
    }

    const rows = this.mfs
      .map((mf) => {
        const pct = Math.round((d.mems[mf.name] || 0) * 100)
        return `<div style="display:flex;justify-content:space-between;gap:14px;">
        <span style="color:${mf.color};">■ ${mf.name}</span>
        <span style="color:#e5e7eb;">${pct}%</span>
      </div>`
      })
      .join("")

    const hostRect = this.el.getBoundingClientRect()
    this.tip.innerHTML = `<div style="margin-bottom:4px;color:#9ca3af;">${d.date}</div>${rows}`
    this.tip.style.left = event.clientX - hostRect.left + 14 + "px"
    this.tip.style.top = event.clientY - hostRect.top + 14 + "px"
    this.tip.style.opacity = "1"
  },

  destroyed() {
    if (this.svg) {
      this.svg.removeEventListener("mousemove", this.onMove)
      this.svg.removeEventListener("mouseleave", this.onLeave)
    }
  },
}
