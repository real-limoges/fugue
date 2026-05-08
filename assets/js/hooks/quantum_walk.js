// Classical vs quantum random walk overlay with a decoherence slider.
//
// Classical: analytic binomial after N steps, P(k) = C(N,(N+k)/2) / 2^N.
// Quantum: Hadamard walk with a coin qubit. Decoherence is implemented as
// stochastic phase flips on the coin (the |1> branch gets multiplied by -1
// with probability p each step), averaged over an ensemble of trajectories.
// p=0 → clean two-horn ballistic spread. p=1 → classical bell. The slider
// is the dial that turns one into the other.

const TRAJECTORIES = 240
const QUANTUM_COLOR = "#22d3ee"
const CLASSICAL_FILL = "rgba(203, 213, 225, 0.18)"
const CLASSICAL_STROKE = "rgba(203, 213, 225, 0.55)"
const AXIS_COLOR = "rgba(148, 163, 184, 0.35)"
const LABEL_COLOR = "rgba(148, 163, 184, 0.75)"

function classicalDistribution(steps) {
  const W = 2 * steps + 1
  const P = new Float64Array(W)
  const logFact = new Float64Array(steps + 1)
  for (let i = 1; i <= steps; i++) logFact[i] = logFact[i - 1] + Math.log(i)
  const logTwoN = steps * Math.log(2)
  for (let k = -steps; k <= steps; k += 2) {
    const heads = (steps + k) / 2
    const logP = logFact[steps] - logFact[heads] - logFact[steps - heads] - logTwoN
    P[k + steps] = Math.exp(logP)
  }
  return P
}

function quantumDistribution(steps, decoherence) {
  const W = 2 * steps + 1
  const P = new Float64Array(W)
  const ensemble = decoherence > 0 ? TRAJECTORIES : 1
  const sqrt2inv = 1 / Math.SQRT2

  let re = new Float64Array(W * 2)
  let im = new Float64Array(W * 2)
  let nextRe = new Float64Array(W * 2)
  let nextIm = new Float64Array(W * 2)

  for (let traj = 0; traj < ensemble; traj++) {
    re.fill(0)
    im.fill(0)
    // Start at origin (index = steps) in the symmetric superposition
    // (|0> + i|1>) / sqrt(2). This makes the two horns equal height.
    re[steps * 2 + 0] = sqrt2inv
    im[steps * 2 + 1] = sqrt2inv

    for (let step = 0; step < steps; step++) {
      nextRe.fill(0)
      nextIm.fill(0)

      for (let x = 0; x < W; x++) {
        const r0 = re[x * 2 + 0]
        const i0 = im[x * 2 + 0]
        const r1 = re[x * 2 + 1]
        const i1 = im[x * 2 + 1]

        if (r0 === 0 && i0 === 0 && r1 === 0 && i1 === 0) continue

        // Hadamard on the coin
        let a0r = (r0 + r1) * sqrt2inv
        let a0i = (i0 + i1) * sqrt2inv
        let a1r = (r0 - r1) * sqrt2inv
        let a1i = (i0 - i1) * sqrt2inv

        // Phase damping: flip the |1> branch with probability p.
        if (decoherence > 0 && Math.random() < decoherence) {
          a1r = -a1r
          a1i = -a1i
        }

        // Shift: coin 0 → x-1, coin 1 → x+1
        if (x > 0) {
          nextRe[(x - 1) * 2 + 0] += a0r
          nextIm[(x - 1) * 2 + 0] += a0i
        }
        if (x < W - 1) {
          nextRe[(x + 1) * 2 + 1] += a1r
          nextIm[(x + 1) * 2 + 1] += a1i
        }
      }

      ;[re, nextRe] = [nextRe, re]
      ;[im, nextIm] = [nextIm, im]
    }

    for (let x = 0; x < W; x++) {
      const r0 = re[x * 2 + 0],
        i0 = im[x * 2 + 0]
      const r1 = re[x * 2 + 1],
        i1 = im[x * 2 + 1]
      P[x] += r0 * r0 + i0 * i0 + r1 * r1 + i1 * i1
    }
  }

  if (ensemble > 1) {
    for (let x = 0; x < W; x++) P[x] /= ensemble
  }
  return P
}

function draw(canvas, steps, classical, quantum) {
  const ctx = canvas.getContext("2d")
  const dpr = window.devicePixelRatio || 1
  const cssWidth = canvas.clientWidth
  const cssHeight = canvas.clientHeight

  if (canvas.width !== cssWidth * dpr || canvas.height !== cssHeight * dpr) {
    canvas.width = cssWidth * dpr
    canvas.height = cssHeight * dpr
  }

  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  ctx.clearRect(0, 0, cssWidth, cssHeight)

  const padL = 36
  const padR = 16
  const padT = 16
  const padB = 36
  const plotW = cssWidth - padL - padR
  const plotH = cssHeight - padT - padB

  // Find shared y-scale (only odd parity slots are populated for both walks
  // when steps is even, and even parity when steps is odd — they share the
  // same support).
  let maxP = 0
  for (let i = 0; i < classical.length; i++) {
    if (classical[i] > maxP) maxP = classical[i]
    if (quantum[i] > maxP) maxP = quantum[i]
  }
  if (maxP === 0) return
  const yMax = maxP * 1.1

  const W = classical.length
  const xToPx = (x) => padL + (x / (W - 1)) * plotW
  const yToPx = (p) => padT + plotH - (p / yMax) * plotH

  // Axes
  ctx.strokeStyle = AXIS_COLOR
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(padL, padT + plotH)
  ctx.lineTo(padL + plotW, padT + plotH)
  ctx.stroke()

  // Center tick
  const centerX = xToPx(steps)
  ctx.beginPath()
  ctx.moveTo(centerX, padT + plotH)
  ctx.lineTo(centerX, padT + plotH + 4)
  ctx.stroke()

  ctx.fillStyle = LABEL_COLOR
  ctx.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace"
  ctx.textAlign = "center"
  ctx.fillText("0", centerX, padT + plotH + 16)
  ctx.textAlign = "left"
  ctx.fillText(`-${steps}`, padL, padT + plotH + 16)
  ctx.textAlign = "right"
  ctx.fillText(`+${steps}`, padL + plotW, padT + plotH + 16)

  // Build a list of populated points (skip empty parity slots so the lines
  // are smooth instead of zigzagging through zeros).
  const points = (arr) => {
    const out = []
    for (let i = 0; i < W; i++) {
      if (arr[i] > 0) out.push([xToPx(i), yToPx(arr[i])])
    }
    return out
  }

  // Classical: filled area
  const cPts = points(classical)
  if (cPts.length > 0) {
    ctx.fillStyle = CLASSICAL_FILL
    ctx.beginPath()
    ctx.moveTo(cPts[0][0], padT + plotH)
    for (const [x, y] of cPts) ctx.lineTo(x, y)
    ctx.lineTo(cPts[cPts.length - 1][0], padT + plotH)
    ctx.closePath()
    ctx.fill()

    ctx.strokeStyle = CLASSICAL_STROKE
    ctx.lineWidth = 1.25
    ctx.beginPath()
    cPts.forEach(([x, y], idx) => (idx === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)))
    ctx.stroke()
  }

  // Quantum: solid line
  const qPts = points(quantum)
  if (qPts.length > 0) {
    ctx.strokeStyle = QUANTUM_COLOR
    ctx.lineWidth = 2
    ctx.lineJoin = "round"
    ctx.beginPath()
    qPts.forEach(([x, y], idx) => (idx === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)))
    ctx.stroke()
  }

  // Legend
  ctx.font = "11px ui-sans-serif, system-ui, sans-serif"
  ctx.textAlign = "left"
  const legendY = padT + 4
  let legendX = padL + 8

  ctx.fillStyle = CLASSICAL_STROKE
  ctx.fillRect(legendX, legendY + 4, 14, 8)
  ctx.fillStyle = LABEL_COLOR
  ctx.fillText("classical", legendX + 20, legendY + 12)

  legendX += 90
  ctx.strokeStyle = QUANTUM_COLOR
  ctx.lineWidth = 2
  ctx.beginPath()
  ctx.moveTo(legendX, legendY + 8)
  ctx.lineTo(legendX + 14, legendY + 8)
  ctx.stroke()
  ctx.fillStyle = LABEL_COLOR
  ctx.fillText("quantum", legendX + 20, legendY + 12)
}

export const QuantumWalk = {
  mounted() {
    this.steps = parseInt(this.el.dataset.steps, 10)
    this.decoherence = parseFloat(this.el.dataset.decoherence)
    this.recompute()

    this.handleEvent("quantum_walk:set_params", ({ steps, decoherence }) => {
      this.steps = parseInt(steps, 10)
      this.decoherence = parseFloat(decoherence)
      this.recompute()
    })

    this.resizeObserver = new ResizeObserver(() => this.render())
    this.resizeObserver.observe(this.el)
  },

  destroyed() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
  },

  recompute() {
    this.classical = classicalDistribution(this.steps)
    this.quantum = quantumDistribution(this.steps, this.decoherence)
    this.render()
  },

  render() {
    if (!this.classical || !this.quantum) return
    draw(this.el, this.steps, this.classical, this.quantum)
  },
}
