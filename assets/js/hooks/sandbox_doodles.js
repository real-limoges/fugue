function resolvePrimary() {
  const raw = getComputedStyle(document.documentElement)
    .getPropertyValue("--color-primary")
    .trim()
  return raw || "oklch(72% 0.19 340)"
}

function sizeCanvas(canvas) {
  const rect = canvas.getBoundingClientRect()
  const w = Math.max(1, Math.floor(rect.width) || canvas.clientWidth || 320)
  const h = Math.max(1, Math.floor(rect.height) || canvas.clientHeight || 220)
  canvas.width = w
  canvas.height = h
  return { w, h }
}

export const LissajousDoodle = {
  async mounted() {
    await new Promise((r) => requestAnimationFrame(r))
    const canvas = this.el
    const { w, h } = sizeCanvas(canvas)
    const ctx = canvas.getContext("2d")

    const cx = w / 2
    const cy = h / 2
    const rx = w * 0.4
    const ry = h * 0.4

    let a = 3
    let b = 2
    let aTarget = 3
    let bTarget = 2
    let delta = 0
    let holdFrames = 0

    const pickTargets = () => {
      aTarget = 1 + Math.floor(Math.random() * 5)
      bTarget = 1 + Math.floor(Math.random() * 5)
      if (aTarget === bTarget) bTarget = (bTarget % 5) + 1
    }

    const draw = () => {
      ctx.clearRect(0, 0, w, h)
      ctx.strokeStyle = resolvePrimary()
      ctx.lineWidth = 1.25
      ctx.beginPath()
      const samples = 480
      for (let i = 0; i <= samples; i++) {
        const u = (i / samples) * Math.PI * 2
        const x = cx + rx * Math.sin(a * u + delta)
        const y = cy + ry * Math.sin(b * u)
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      ctx.stroke()

      delta += 0.006
      a += (aTarget - a) * 0.006
      b += (bTarget - b) * 0.006

      if (Math.abs(a - aTarget) < 0.01 && Math.abs(b - bTarget) < 0.01) {
        holdFrames++
        if (holdFrames > 180) {
          pickTargets()
          holdFrames = 0
        }
      }

      this._raf = requestAnimationFrame(draw)
    }
    draw()
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
  },
}

export const Rule30Doodle = {
  async mounted() {
    await new Promise((r) => requestAnimationFrame(r))
    const canvas = this.el
    const { w, h } = sizeCanvas(canvas)
    const ctx = canvas.getContext("2d")

    const cell = 3
    const cols = Math.floor(w / cell)
    const rows = Math.floor(h / cell)
    const startRow = () => {
      const s = new Uint8Array(cols)
      s[Math.floor(cols / 2)] = 1
      return s
    }

    let state = startRow()
    let row = 0

    const reset = () => {
      ctx.clearRect(0, 0, w, h)
      state = startRow()
      row = 0
    }

    const tick = () => {
      ctx.fillStyle = resolvePrimary()
      for (let i = 0; i < cols; i++) {
        if (state[i]) ctx.fillRect(i * cell, row * cell, cell, cell)
      }

      const next = new Uint8Array(cols)
      for (let i = 0; i < cols; i++) {
        const l = state[(i - 1 + cols) % cols]
        const c = state[i]
        const r = state[(i + 1) % cols]
        next[i] = l ^ (c | r)
      }
      state = next
      row++

      if (row >= rows) {
        this._timer = setTimeout(() => {
          reset()
          this._timer = setTimeout(tick, 60)
        }, 1200)
        return
      }

      this._timer = setTimeout(tick, 60)
    }
    tick()
  },

  destroyed() {
    if (this._timer) clearTimeout(this._timer)
  },
}
