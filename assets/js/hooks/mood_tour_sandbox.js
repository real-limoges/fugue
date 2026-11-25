// @ts-check
// Interactive sandbox for teaching fuzzy clustering.
// The markup and geometry are server-rendered (Sections.tour_sandbox in
// FugueWeb.MoodLive.Sections); this hook only moves the point and redraws
// the centers and the membership bar. Everything runs in the browser, since
// a drag can't wait on a round trip. Styles are in assets/css/mood_tour.css.

import { requireElement } from "../lib/dom.js"

const BAR_GAP = 1.5

// Okabe-Ito on dark, darkened to clear 3:1 on the paper in light; up to 5
// clusters. Values are per theme in assets/css/palettes/mood.css.
const COLORS = [0, 1, 2, 3, 4].map((i) => `var(--mood-sandbox-${i})`)

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
 * @typedef {object} Geometry
 * @property {number} padX left edge of the axis, in viewBox units
 * @property {number} innerW axis length
 * @property {number} axisY
 * @property {number} barH
 */

/**
 * @typedef {object} State
 * @property {{pointX: number, m: number, k: number}} state point on [0, 1], fuzziness, cluster count
 * @property {boolean} dragging
 * @property {Geometry} geom
 * @property {SVGSVGElement} svg
 * @property {SVGCircleElement} pointEl
 * @property {SVGGElement} centersG
 * @property {SVGGElement} barG
 * @property {SVGRectElement} hitbox
 * @property {HTMLInputElement} mInput
 * @property {HTMLInputElement} kInput
 */

/**
 * @typedef {object} Methods
 * @property {() => void} wireInteractions
 * @property {() => void} update
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const MoodTourSandbox = {
  mounted() {
    const data = this.el.dataset
    this.geom = {
      padX: Number(data.padX),
      innerW: Number(data.innerW),
      axisY: Number(data.axisY),
      barH: Number(data.barH),
    }
    this.svg = requireElement(this.el, ".sandbox-svg", SVGSVGElement)
    this.pointEl = requireElement(this.el, ".point", SVGCircleElement)
    this.centersG = requireElement(this.el, ".centers", SVGGElement)
    this.barG = requireElement(this.el, ".bar", SVGGElement)
    this.hitbox = requireElement(this.el, ".hitbox", SVGRectElement)
    this.mInput = requireElement(this.el, 'input[data-control="m"]', HTMLInputElement)
    this.kInput = requireElement(this.el, 'input[data-control="k"]', HTMLInputElement)

    this.state = {
      pointX: 0.42,
      m: parseFloat(this.mInput.value),
      k: parseInt(this.kInput.value, 10),
    }
    this.dragging = false
    this.wireInteractions()
    this.update()
  },

  wireInteractions() {
    const { padX, innerW } = this.geom

    // The pointer's position along the axis, 0 to 1. getScreenCTM is null
    // while the SVG is not rendered; the point then stays where it was.
    /** @param {PointerEvent} e */
    const pointerToNorm = (e) => {
      const ctm = this.svg.getScreenCTM()
      if (!ctm) return this.state.pointX
      const svgP = new DOMPoint(e.clientX, e.clientY).matrixTransform(ctm.inverse())
      return Math.max(0, Math.min(1, (svgP.x - padX) / innerW))
    }

    this.hitbox.addEventListener("pointerdown", (e) => {
      this.dragging = true
      this.hitbox.setPointerCapture(e.pointerId)
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
      this.pointEl.setAttribute("r", "8")
    }
    this.hitbox.addEventListener("pointerup", release)
    this.hitbox.addEventListener("pointercancel", release)

    this.mInput.addEventListener("input", () => {
      this.state.m = parseFloat(this.mInput.value)
      this.update()
    })
    this.kInput.addEventListener("input", () => {
      this.state.k = parseInt(this.kInput.value, 10)
      this.update()
    })
  },

  update() {
    const { padX, innerW, axisY, barH } = this.geom
    const { pointX, m, k } = this.state
    const centers = centersFor(k)
    const ms = memberships(pointX, centers, m)

    this.pointEl.setAttribute("cx", String(padX + pointX * innerW))

    this.centersG.innerHTML = centers
      .map((c, i) => `<circle cx="${padX + c * innerW}" cy="${axisY}" r="4" fill="${COLORS[i]}"/>`)
      .join("")

    let xAcc = 0
    this.barG.innerHTML = centers
      .map((_, i) => {
        const rawW = ms[i] * innerW
        const w = Math.max(0, rawW - BAR_GAP)
        const seg = `<rect x="${xAcc}" y="0" width="${w}" height="${barH}" rx="2" ry="2" fill="${COLORS[i]}" opacity="0.92"/>`
        xAcc += rawW
        return seg
      })
      .join("")

    requireElement(this.el, '[data-readout="m"]', HTMLElement).textContent = m.toFixed(2)
    requireElement(this.el, '[data-readout="k"]', HTMLElement).textContent = String(k)
  },
}
