// @ts-check
// Interactive sandbox for teaching fuzzy clustering.
// Self-contained: fake centers, a draggable point, live-computed memberships.
// No server round-trips; everything is client-side.

import { requireElement } from "../lib/dom.js"

const VB_W = 500
const VB_H = 150
const PAD_X = 40
const AXIS_Y = 45
const BAR_Y = 82
const BAR_H = 22
const BAR_GAP = 1.5
const INNER_W = VB_W - 2 * PAD_X

// Okabe-Ito: colorblind-safe palette, high contrast, up to 5 clusters.
const COLORS = ["#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#F0E442"]

const STYLES = `
  #mood-tour-sandbox .sandbox-svg {
    width: 100%;
    max-width: 640px;
    display: block;
    margin: 0 auto;
    touch-action: none;
    user-select: none;
  }
  #mood-tour-sandbox .bar rect {
    transition: width 110ms ease-out, x 110ms ease-out;
  }
  #mood-tour-sandbox.dragging-point .bar rect {
    transition: none;
  }
  #mood-tour-sandbox .sandbox-sliders {
    max-width: 640px;
    margin: 1rem auto 0;
    display: flex;
    flex-direction: column;
    gap: 0.7rem;
  }
  #mood-tour-sandbox .sandbox-sliders label {
    display: flex;
    align-items: center;
    gap: 1rem;
    color: #6b7280;
  }
  #mood-tour-sandbox .sandbox-sliders .label-text {
    min-width: 5.25rem;
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
  }
  #mood-tour-sandbox .sandbox-sliders .readout {
    min-width: 2.25rem;
    text-align: right;
    color: #9ca3af;
    font-size: 0.7rem;
    font-variant-numeric: tabular-nums;
  }
  #mood-tour-sandbox input[type=range] {
    -webkit-appearance: none;
    appearance: none;
    flex: 1;
    height: 2px;
    background: #2f2f2f;
    border-radius: 1px;
    outline: none;
    cursor: pointer;
  }
  #mood-tour-sandbox input[type=range]::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: #e5e7eb;
    border: none;
    cursor: grab;
    transition: transform 120ms ease, background 120ms ease;
  }
  #mood-tour-sandbox input[type=range]::-webkit-slider-thumb:hover {
    transform: scale(1.15);
    background: #ffffff;
  }
  #mood-tour-sandbox input[type=range]::-webkit-slider-thumb:active {
    cursor: grabbing;
    transform: scale(1.25);
  }
  #mood-tour-sandbox input[type=range]::-moz-range-track {
    height: 2px;
    background: #2f2f2f;
    border: none;
    border-radius: 1px;
  }
  #mood-tour-sandbox input[type=range]::-moz-range-thumb {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: #e5e7eb;
    border: none;
    cursor: grab;
    transition: transform 120ms ease, background 120ms ease;
  }
  #mood-tour-sandbox input[type=range]::-moz-range-thumb:hover {
    transform: scale(1.15);
    background: #ffffff;
  }
  #mood-tour-sandbox input[type=range]:focus-visible {
    outline: 1px solid #6b7280;
    outline-offset: 4px;
    border-radius: 2px;
  }
`

/**
 * `k` evenly spaced cluster centers on [0, 1], inset from the ends.
 * @param {number} k
 * @returns {number[]}
 */
function centersFor(k) {
  if (k === 1) return [0.5]
  const margin = 0.12
  return Array.from({ length: k }, (_, i) => margin + (i / (k - 1)) * (1 - 2 * margin))
}

/**
 * Fuzzy c-means membership of `x` in each center at fuzziness `m`.
 * Sums to 1; a point on a center belongs to it entirely.
 * @param {number} x
 * @param {number[]} centers
 * @param {number} m
 * @returns {number[]}
 */
function memberships(x, centers, m) {
  const dists = centers.map((c) => Math.abs(x - c))
  const minD = Math.min(...dists)
  if (minD < 1e-6) {
    return centers.map((_, i) => (dists[i] === minD ? 1 : 0))
  }
  const exponent = 2 / (m - 1)
  return dists.map((di) => 1 / dists.reduce((sum, dj) => sum + Math.pow(di / dj, exponent), 0))
}

/**
 * @typedef {object} State
 * @property {{pointX: number, m: number, k: number}} state point on [0, 1], fuzziness, cluster count
 * @property {boolean} dragging
 * @property {SVGSVGElement} svg
 * @property {SVGCircleElement} pointEl
 * @property {SVGGElement} centersG
 * @property {SVGGElement} barG
 * @property {SVGRectElement} hitbox
 */

/**
 * @typedef {object} Methods
 * @property {() => void} buildDom
 * @property {() => void} wireInteractions
 * @property {() => void} update
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const MoodTourSandbox = {
  mounted() {
    this.state = { pointX: 0.42, m: 2.0, k: 3 }
    this.dragging = false
    this.buildDom()
    this.wireInteractions()
    this.update()
  },

  buildDom() {
    this.el.innerHTML = `
      <style>${STYLES}</style>
      <svg class="sandbox-svg" viewBox="0 0 ${VB_W} ${VB_H}" preserveAspectRatio="xMidYMid meet">
        <line x1="${PAD_X}" y1="${AXIS_Y}" x2="${VB_W - PAD_X}" y2="${AXIS_Y}" stroke="#666" stroke-width="1"/>
        <g class="centers"></g>
        <g class="bar" transform="translate(${PAD_X},${BAR_Y})"></g>
        <circle class="point" cx="${PAD_X}" cy="${AXIS_Y}" r="8" fill="#f5f5f5" stroke="#111" stroke-width="1"/>
        <rect class="hitbox" x="${PAD_X - 24}" y="${AXIS_Y - 28}" width="${INNER_W + 48}" height="56"
              fill="transparent" style="cursor:grab"/>
      </svg>
      <div class="sandbox-sliders">
        <label>
          <span class="label-text">Fuzziness</span>
          <input data-control="m" type="range" min="1.05" max="4" step="0.05" value="2"/>
          <span class="readout" data-readout="m">2.00</span>
        </label>
        <label>
          <span class="label-text">Clusters</span>
          <input data-control="k" type="range" min="2" max="5" step="1" value="3"/>
          <span class="readout" data-readout="k">3</span>
        </label>
      </div>
    `

    this.svg = requireElement(this.el, ".sandbox-svg", SVGSVGElement)
    this.pointEl = requireElement(this.el, ".point", SVGCircleElement)
    this.centersG = requireElement(this.el, ".centers", SVGGElement)
    this.barG = requireElement(this.el, ".bar", SVGGElement)
    this.hitbox = requireElement(this.el, ".hitbox", SVGRectElement)
  },

  wireInteractions() {
    // The pointer's position along the axis, 0 to 1. getScreenCTM is null
    // while the SVG is not rendered; the point then stays where it was.
    /** @param {PointerEvent} e */
    const pointerToNorm = (e) => {
      const ctm = this.svg.getScreenCTM()
      if (!ctm) return this.state.pointX
      const svgP = new DOMPoint(e.clientX, e.clientY).matrixTransform(ctm.inverse())
      return Math.max(0, Math.min(1, (svgP.x - PAD_X) / INNER_W))
    }

    this.hitbox.addEventListener("pointerdown", (e) => {
      this.dragging = true
      this.el.classList.add("dragging-point")
      this.hitbox.setPointerCapture(e.pointerId)
      this.hitbox.style.cursor = "grabbing"
      this.pointEl.setAttribute("r", "9")
      this.state.pointX = pointerToNorm(e)
      this.update()
    })
    this.hitbox.addEventListener("pointermove", (e) => {
      if (!this.dragging) return
      this.state.pointX = pointerToNorm(e)
      this.update()
    })
    const release = () => {
      this.dragging = false
      this.el.classList.remove("dragging-point")
      this.hitbox.style.cursor = "grab"
      this.pointEl.setAttribute("r", "8")
    }
    this.hitbox.addEventListener("pointerup", release)
    this.hitbox.addEventListener("pointercancel", release)

    const mInput = requireElement(this.el, 'input[data-control="m"]', HTMLInputElement)
    mInput.addEventListener("input", () => {
      this.state.m = parseFloat(mInput.value)
      this.update()
    })
    const kInput = requireElement(this.el, 'input[data-control="k"]', HTMLInputElement)
    kInput.addEventListener("input", () => {
      this.state.k = parseInt(kInput.value, 10)
      this.update()
    })
  },

  update() {
    const { pointX, m, k } = this.state
    const centers = centersFor(k)
    const ms = memberships(pointX, centers, m)

    this.pointEl.setAttribute("cx", String(PAD_X + pointX * INNER_W))

    this.centersG.innerHTML = centers
      .map((c, i) => {
        const cx = PAD_X + c * INNER_W
        return `<circle cx="${cx}" cy="${AXIS_Y}" r="4" fill="${COLORS[i]}"/>`
      })
      .join("")

    let xAcc = 0
    this.barG.innerHTML = centers
      .map((_, i) => {
        const rawW = ms[i] * INNER_W
        const w = Math.max(0, rawW - BAR_GAP)
        const seg = `<rect x="${xAcc}" y="0" width="${w}" height="${BAR_H}" rx="2" ry="2" fill="${COLORS[i]}" opacity="0.92"/>`
        xAcc += rawW
        return seg
      })
      .join("")

    requireElement(this.el, '[data-readout="m"]', HTMLElement).textContent = m.toFixed(2)
    requireElement(this.el, '[data-readout="k"]', HTMLElement).textContent = String(k)
  },
}
