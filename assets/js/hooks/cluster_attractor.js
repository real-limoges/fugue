/** A slowly drawn Thomas strange attractor, tinted by the user's cluster palette.
 *  Generative filler; no data, just a living scribble that rhymes with the trajectory hero. */

const B = 0.208186
const STEP = 0.02
const SEGS_PER_FRAME = 6
const WARMUP_STEPS = 6000
const FADE = "rgba(10,10,26,0.035)"
const LINE_WIDTH = 1.1
const LINE_ALPHA = 0.78
const FALLBACK_ASPECT = 0.62
const BG = "rgb(10,10,26)"

function thomasStep(p) {
  const [x, y, z] = p
  return [
    x + STEP * (Math.sin(y) - B * x),
    y + STEP * (Math.sin(z) - B * y),
    z + STEP * (Math.sin(x) - B * z),
  ]
}

export const ClusterAttractor = {
  mounted() {
    const raw = this.el.dataset.colors || "[]"
    try {
      this.palette = JSON.parse(raw).filter((c) => typeof c === "string" && c.length > 0)
    } catch {
      this.palette = []
    }
    if (this.palette.length === 0) {
      this.palette = ["#b266ff", "#22d3ee", "#f472b6", "#facc15", "#4ade80"]
    }

    this.warmup()
    this.setupCanvas()
    this.loop = this.loop.bind(this)
    this._raf = requestAnimationFrame(this.loop)

    this._onResize = () => this.setupCanvas()
    window.addEventListener("resize", this._onResize)

    if (typeof ResizeObserver !== "undefined") {
      this._ro = new ResizeObserver(() => this.setupCanvas())
      this._ro.observe(this.el)
    }
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
    window.removeEventListener("resize", this._onResize)
    if (this._ro) this._ro.disconnect()
  },

  warmup() {
    let p = [0.1, 0.0, 0.0]
    const samples = []
    let xMin = Infinity,
      xMax = -Infinity,
      yMin = Infinity,
      yMax = -Infinity

    for (let i = 0; i < WARMUP_STEPS; i++) {
      p = thomasStep(p)
      if (i > WARMUP_STEPS / 3) {
        samples.push(p)
        if (p[0] < xMin) xMin = p[0]
        if (p[0] > xMax) xMax = p[0]
        if (p[1] < yMin) yMin = p[1]
        if (p[1] > yMax) yMax = p[1]
      }
    }

    this.bounds = { xMin, xMax, yMin, yMax }
    this.p = p

    const stride = Math.floor(samples.length / this.palette.length)
    this.basins = this.palette.map((color, i) => {
      const s = samples[((i + 0.5) * stride) | 0] || samples[0]
      return { x: s[0], y: s[1], z: s[2], color }
    })
  },

  setupCanvas() {
    const w = Math.max(this.el.clientWidth || 0, 240)
    const measuredH = this.el.clientHeight || 0
    const h = Math.max(measuredH, Math.round(w * FALLBACK_ASPECT))

    if (this.canvas && this.w === w && this.h === h) return

    this.el.innerHTML = ""
    const dpr = window.devicePixelRatio || 1

    const canvas = document.createElement("canvas")
    canvas.width = w * dpr
    canvas.height = h * dpr
    canvas.style.width = w + "px"
    canvas.style.height = h + "px"
    canvas.style.display = "block"
    canvas.style.borderRadius = "6px"
    this.el.appendChild(canvas)

    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)
    ctx.fillStyle = BG
    ctx.fillRect(0, 0, w, h)

    this.canvas = canvas
    this.ctx = ctx
    this.w = w
    this.h = h
    this.cacheProjection()
    this.prev = this.project(this.p)
  },

  cacheProjection() {
    const { xMin, xMax, yMin, yMax } = this.bounds
    const pad = 24
    const dataW = xMax - xMin
    const dataH = yMax - yMin
    const sx = (this.w - pad * 2) / dataW
    const sy = (this.h - pad * 2) / dataH
    this._projScale = Math.min(sx, sy)
    this._projCx = this.w / 2
    this._projCy = this.h / 2
    this._projXMid = (xMin + xMax) / 2
    this._projYMid = (yMin + yMax) / 2
  },

  project(p) {
    return [
      this._projCx + (p[0] - this._projXMid) * this._projScale,
      this._projCy + (p[1] - this._projYMid) * this._projScale,
    ]
  },

  nearestColor(p) {
    let best = this.basins[0]
    let bestD = Infinity
    for (const b of this.basins) {
      const dx = p[0] - b.x
      const dy = p[1] - b.y
      const dz = p[2] - b.z
      const d = dx * dx + dy * dy + dz * dz
      if (d < bestD) {
        bestD = d
        best = b
      }
    }
    return best.color
  },

  loop() {
    const ctx = this.ctx
    ctx.fillStyle = FADE
    ctx.fillRect(0, 0, this.w, this.h)

    ctx.globalAlpha = LINE_ALPHA
    ctx.lineWidth = LINE_WIDTH
    ctx.lineCap = "round"

    for (let i = 0; i < SEGS_PER_FRAME; i++) {
      this.p = thomasStep(this.p)
      const curr = this.project(this.p)
      ctx.strokeStyle = this.nearestColor(this.p)
      ctx.beginPath()
      ctx.moveTo(this.prev[0], this.prev[1])
      ctx.lineTo(curr[0], curr[1])
      ctx.stroke()
      this.prev = curr
    }

    ctx.globalAlpha = 1
    this._raf = requestAnimationFrame(this.loop)
  },
}
