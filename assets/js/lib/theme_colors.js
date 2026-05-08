// Theme-color helpers for the petri-style intensity splashes (boids,
// sandpile, langton, oscillators). DaisyUI exposes its theme as oklch CSS
// custom properties; canvas 2D won't accept oklch as a color, so we paint
// it onto a 1x1 probe and read the rendered RGBA back. The color table is
// a precomputed gradient lookup the per-pixel render loop indexes into.

const FALLBACK_BASE = [28, 19, 37]
const FALLBACK_PRIMARY = [200, 50, 180]

export function resolveThemeColors() {
  const style = getComputedStyle(document.documentElement)
  const baseProp = style.getPropertyValue("--color-base-100").trim()
  const primaryProp = style.getPropertyValue("--color-primary").trim()

  const probe = document.createElement("canvas")
  probe.width = 1
  probe.height = 1
  const pctx = probe.getContext("2d", { willReadFrequently: true })

  return {
    base: paintAndRead(pctx, baseProp, FALLBACK_BASE),
    primary: paintAndRead(pctx, primaryProp, FALLBACK_PRIMARY),
  }
}

export function buildColorTable(base, primary) {
  const table = new Uint8Array(256 * 4)
  for (let i = 0; i < 256; i++) {
    const t = i / 255
    const t2 = t * t
    const offset = i * 4
    table[offset] = base[0] + Math.round((primary[0] - base[0]) * t2)
    table[offset + 1] = base[1] + Math.round((primary[1] - base[1]) * t2)
    table[offset + 2] = base[2] + Math.round((primary[2] - base[2]) * t2)
    table[offset + 3] = 255
  }
  return table
}

function paintAndRead(pctx, oklchStr, fallback) {
  if (!oklchStr) return fallback
  pctx.clearRect(0, 0, 1, 1)
  pctx.fillStyle = oklchStr
  pctx.fillRect(0, 0, 1, 1)
  const [r, g, b] = pctx.getImageData(0, 0, 1, 1).data
  return [r, g, b]
}
