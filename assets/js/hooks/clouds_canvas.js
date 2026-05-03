import * as clouds from "../../vendor/petri/js/clouds.js"

// Composition lives here. The WASM is physics-only -- it gives us a
// raw qc field (NX*NZ Float32Array) and an applyBubble primitive. We
// pick the view window, palette, tones, and forcing schedule.

// --- Render config -----------------------------------------------------

const CANVAS_W = 800   // internal canvas resolution; CSS upscales
const CANVAS_H = 400

// World-coordinate window we show
const VIEW_X0 =  500   // m
const VIEW_X1 = 5500   // m  (5 km wide)
const VIEW_Z0 =    0   // m
const VIEW_Z1 = 2500   // m  (2.5 km tall)

// Sky gradient: smooth lerp horizon -> zenith. No bands -- the band look
// fights the painterly clouds.
const SKY_ZENITH  = [ 32,  72, 140]   // deep cobalt
const SKY_HORIZON = [244, 220, 188]   // warm peach

// Cloud rendering knobs
const QC_LO = 0.00008   // soft alpha: fully transparent below
const QC_HI = 0.00025   // fully opaque above
const SUN_X = 0.6       // sun direction in world coords (right and up)
const SUN_Z = 0.8
const H_GRAD = 60       // m, finite-difference spacing for normal
const SHADOW_STEP_M = 60
const SHADOW_SAMPLES = 6
const TRANSMIT_K = 350  // optical-depth coefficient (lower = brighter cores)

// 3-stop luminance ramp for cloud color. Lightness is the volume cue;
// hue is decorative. Pumped contrast (deep cool shadow -> warm-white
// highlight) to match real cumulus.
const RAMP_SHADOW = [ 36,  52,  84]
const RAMP_MID    = [180, 188, 208]
const RAMP_HI     = [255, 252, 240]

// Sub-grid cauliflower. Two octaves drive different things:
//   * coarse fBm displaces qc -> lumpy cluster silhouette
//   * fine fBm perturbs the surface normal -> directional bump-lighting
//     so lit-side bumps catch light and shadow-side bumps stay dark
const FBM_FREQ_COARSE = 0.005   // 1/m (~200 m silhouette features)
const FBM_FREQ_FINE   = 0.020   // 1/m (~50 m bump features)
const FBM_QC_AMP      = 0.00022 // qc displacement amplitude
// Tuned so noise-gradient magnitude is ~30-60% of the qc-gradient
// magnitude. Noise gradient (~0.5/feature) dwarfs qc gradient (~0.001
// over H_GRAD) without explicit scaling.
const NORMAL_NOISE_AMP = 0.0008
const NORMAL_EPS_M     = 25     // m, finite diff for normal-noise gradient

// --- Foreground (plains + barn) ---------------------------------------

const HORIZON_PY = 300  // top of ground band (px from top of canvas)

// Ground bands: each entry is [py_start, [r,g,b]]; last band runs to bottom.
const GROUND_BANDS = [
  [300, [156, 168, 110]],  // far hazy green
  [312, [140, 158,  92]],
  [328, [122, 146,  78]],
  [348, [104, 132,  66]],
  [372, [ 88, 118,  56]],
]

// Barn palette
const BARN_RED  = [156,  56,  48]
const BARN_DARK = [104,  36,  32]
const BARN_TRIM = [232, 224, 200]
const BARN_ROOF = [ 56,  44,  40]
const BARN_DOOR = [ 36,  28,  28]

// --- Forcing config ----------------------------------------------------

// JS owns when bubbles fire. For now, sustained discrete clusters --
// next step is to swap this for distributed always-on forcing.
const BUBBLE_PERIOD_FRAMES = 350     // sim frames between cluster fires
const STEPS_PER_FRAME = 2

// Pre-seed: drop a curated set of multi-lobed clusters at staggered ages
// so the opening frame already shows 4 cumulus distributed across the
// view, varying maturity left->right. East-coast plains, no storm.

const PRESEED_WIND = 3.0  // m/s (live loop drift)

// Direct-paint cumulus: clouds already exist at altitude, no surface
// thermal spinup. Each cluster is many overlapping Gaussian qc blobs,
// arranged base-wide / tower-narrow for cumulus silhouette.
//
// dx/dz are offsets (m) from the cluster center. sigma is the Gaussian
// 1-sigma radius (visible extent ~ 2.5 sigma). peak is qc at the center
// of the blob.
const LOBES = [
  // base spread
  { dx: -300, dz: -200, sigma: 200, peak: 0.00075 },
  { dx:    0, dz: -180, sigma: 240, peak: 0.00090 },
  { dx:  300, dz: -200, sigma: 200, peak: 0.00075 },
  // mid body 1
  { dx: -200, dz:    0, sigma: 220, peak: 0.00105 },
  { dx:  200, dz:    0, sigma: 220, peak: 0.00105 },
  { dx:    0, dz:   60, sigma: 280, peak: 0.00130 },  // densest core
  // mid body 2
  { dx: -140, dz:  220, sigma: 200, peak: 0.00105 },
  { dx:  140, dz:  220, sigma: 200, peak: 0.00105 },
  // upper
  { dx:    0, dz:  380, sigma: 220, peak: 0.00100 },
  { dx: -100, dz:  500, sigma: 180, peak: 0.00080 },
  { dx:  100, dz:  500, sigma: 180, peak: 0.00080 },
  // crown
  { dx:    0, dz:  680, sigma: 180, peak: 0.00065 },
  { dx: -120, dz:  780, sigma: 140, peak: 0.00050 },
  { dx:  120, dz:  780, sigma: 140, peak: 0.00050 },
]

// Three towering cumulus across the view at altitude. cz is the cluster
// center height (m); cluster bases land around cz - 200 (LCL), crowns at
// cz + 780.
const PRESEED = [
  { cx: 4500, cz: 1450 },
  { cx: 2700, cz: 1500 },
  { cx: 1100, cz: 1400 },
]

// --- Helpers -----------------------------------------------------------

function clamp01(x) { return x < 0 ? 0 : (x > 1 ? 1 : x) }

function smoothstep(a, b, x) {
  const t = clamp01((x - a) / (b - a))
  return t * t * (3 - 2 * t)
}

function lerp3(a, b, t) {
  return [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
  ]
}

// 3-stop ramp: shadow -> mid -> highlight
function sampleRamp3(t) {
  if (t <= 0.5) return lerp3(RAMP_SHADOW, RAMP_MID, t * 2)
  return lerp3(RAMP_MID, RAMP_HI, (t - 0.5) * 2)
}

function skyAt(z_m) {
  const u = smoothstep(0, 1, clamp01(z_m / VIEW_Z1))
  return lerp3(SKY_HORIZON, SKY_ZENITH, u)
}

// 2D value noise + 3-octave fBm. Used as a sub-grid alpha multiplier so
// the smooth WASM qc field grows cauliflower texture.
function hash2(ix, iy) {
  let h = (ix | 0) * 374761393 + (iy | 0) * 668265263
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295
}

function valueNoise(x, y) {
  const ix = Math.floor(x), iy = Math.floor(y)
  const fx = x - ix, fy = y - iy
  const a = hash2(ix,     iy)
  const b = hash2(ix + 1, iy)
  const c = hash2(ix,     iy + 1)
  const d = hash2(ix + 1, iy + 1)
  const ux = fx * fx * (3 - 2 * fx)
  const uy = fy * fy * (3 - 2 * fy)
  return a + (b - a) * ux + ((c - a) + (d - b - c + a) * ux) * uy
}

// Deposit a Gaussian blob of qc directly into the WASM grid. Skips the
// thermal-bubble-rises-and-condenses path entirely -- the cloud is here,
// at altitude, now.
function paintGaussian(qc, NX, NZ, DX, DZ, cx_m, cz_m, sigma_m, peak) {
  const inv2s2 = 1 / (2 * sigma_m * sigma_m)
  const ixMin = Math.max(0, Math.floor((cx_m - 3 * sigma_m) / DX))
  const ixMax = Math.min(NX - 1, Math.ceil((cx_m + 3 * sigma_m) / DX))
  const izMin = Math.max(0, Math.floor((cz_m - 3 * sigma_m) / DZ))
  const izMax = Math.min(NZ - 1, Math.ceil((cz_m + 3 * sigma_m) / DZ))
  for (let iz = izMin; iz <= izMax; iz++) {
    const z_m = (iz + 0.5) * DZ
    for (let ix = ixMin; ix <= ixMax; ix++) {
      const x_m = (ix + 0.5) * DX
      const dx = x_m - cx_m, dz = z_m - cz_m
      const g = Math.exp(-(dx * dx + dz * dz) * inv2s2)
      qc[iz * NX + ix] += peak * g
    }
  }
}

function fbm3(x, y) {
  let v = 0, amp = 0.5, freq = 1
  for (let i = 0; i < 3; i++) {
    v += amp * valueNoise(x * freq, y * freq)
    amp *= 0.5
    freq *= 2
  }
  return v * 1.5  // approx normalize to [0, 1]
}

function makeQcSampler(qc) {
  const NX = clouds.grid.NX, NZ = clouds.grid.NZ
  const DX = clouds.grid.DX, DZ = clouds.grid.DZ
  // Bilinear sample qc at world coords (x_m, z_m). Out-of-domain = 0.
  return (x_m, z_m) => {
    if (z_m < 0 || z_m > (NZ - 1) * DZ) return 0
    let fx = x_m / DX - 0.5
    let fz = z_m / DZ - 0.5
    if (fx < 0) fx = 0
    if (fx > NX - 1.001) fx = NX - 1.001
    if (fz < 0) fz = 0
    if (fz > NZ - 1.001) fz = NZ - 1.001
    const i = fx | 0, j = fz | 0
    const a = fx - i, b = fz - j
    const f00 = qc[j * NX + i]
    const f10 = qc[j * NX + i + 1]
    const f01 = qc[(j + 1) * NX + i]
    const f11 = qc[(j + 1) * NX + i + 1]
    return (1-a)*(1-b)*f00 + a*(1-b)*f10 + (1-a)*b*f01 + a*b*f11
  }
}

function setPx(rgba, px, py, rgb) {
  if (px < 0 || px >= CANVAS_W || py < 0 || py >= CANVAS_H) return
  const off = (py * CANVAS_W + px) * 4
  rgba[off]   = rgb[0]
  rgba[off+1] = rgb[1]
  rgba[off+2] = rgb[2]
  rgba[off+3] = 255
}

function fillRect(rgba, x, y, w, h, rgb) {
  for (let py = y; py < y + h; py++)
    for (let px = x; px < x + w; px++)
      setPx(rgba, px, py, rgb)
}

function drawGround(rgba) {
  for (let py = HORIZON_PY; py < CANVAS_H; py++) {
    let band = GROUND_BANDS[0][1]
    for (const [start, rgb] of GROUND_BANDS) {
      if (py >= start) band = rgb
    }
    for (let px = 0; px < CANVAS_W; px++) setPx(rgba, px, py, band)
  }
}

// Small gable-roof barn sitting on the horizon. Anchored at (bx, by) =
// bottom-left corner of the wall block. Sized for an 800x400 canvas.
function drawBarn(rgba, bx, by) {
  const wallW = 56, wallH = 32
  const wallTop = by - wallH

  // Walls
  fillRect(rgba, bx, wallTop, wallW, wallH, BARN_RED)

  // White trim along the top of the wall (under the eaves)
  fillRect(rgba, bx, wallTop, wallW, 2, BARN_TRIM)

  // Door (centered, double-door dark rectangle)
  const doorW = 16, doorH = 18
  const doorX = bx + ((wallW - doorW) >> 1)
  const doorY = by - doorH
  fillRect(rgba, doorX, doorY, doorW, doorH, BARN_DOOR)
  // Door X-brace (single diagonal hint, dark trim)
  for (let i = 0; i < doorH; i++) {
    setPx(rgba, doorX + Math.round(i * (doorW - 1) / (doorH - 1)), doorY + i, BARN_TRIM)
  }
  // Vertical split between doors
  fillRect(rgba, doorX + (doorW >> 1), doorY, 2, doorH, BARN_DARK)

  // Loft window (small square above door)
  const winSize = 8
  const winX = bx + ((wallW - winSize) >> 1)
  const winY = wallTop + 6
  fillRect(rgba, winX, winY, winSize, winSize, BARN_TRIM)
  fillRect(rgba, winX + (winSize >> 1), winY, 2, winSize, BARN_DARK)
  fillRect(rgba, winX, winY + (winSize >> 1), winSize, 2, BARN_DARK)

  // Gable roof: narrow at peak, widens down to eaves with 4 px overhang
  const roofH = 18
  const peakX = bx + (wallW >> 1)
  const eaveHalf = (wallW >> 1) + 4
  for (let dy = 0; dy < roofH; dy++) {
    const t = dy / (roofH - 1)              // 0 at peak, 1 at eaves
    const halfW = Math.round(t * eaveHalf)
    const y = wallTop - (roofH - 1 - dy)
    fillRect(rgba, peakX - halfW, y, halfW * 2 + 1, 1, BARN_ROOF)
  }
}

function drawForeground(rgba) {
  drawGround(rgba)
  // Barn nestled left-of-center, bottom on the horizon band
  drawBarn(rgba, 192, HORIZON_PY + 16)
}

function renderFrame(rgba, qc) {
  const sample = makeQcSampler(qc)
  const dxView = (VIEW_X1 - VIEW_X0) / (CANVAS_W - 1)
  const dzView = (VIEW_Z1 - VIEW_Z0) / (CANVAS_H - 1)
  let off = 0

  for (let py = 0; py < CANVAS_H; py++) {
    const z_m = VIEW_Z1 - py * dzView
    const sky = skyAt(z_m)
    const skyR = sky[0], skyG = sky[1], skyB = sky[2]

    for (let px = 0; px < CANVAS_W; px++) {
      const x_m = VIEW_X0 + px * dxView
      const qc_raw = sample(x_m, z_m)
      // Coarse fBm displaces qc -> lumpy cauliflower silhouette. Gated
      // by qc_raw so the noise can't conjure clouds out of clear sky.
      const nCoarse = fbm3(x_m * FBM_FREQ_COARSE, z_m * FBM_FREQ_COARSE)
      const gate = smoothstep(0, QC_LO, qc_raw)
      const qc_here = qc_raw + (nCoarse - 0.5) * FBM_QC_AMP * gate
      const alpha = smoothstep(QC_LO, QC_HI, qc_here)

      if (alpha < 0.01) {
        rgba[off]   = skyR
        rgba[off+1] = skyG
        rgba[off+2] = skyB
        rgba[off+3] = 255
        off += 4
        continue
      }

      // Surface normal from -gradient(qc), perturbed by a fine-noise
      // gradient so the smooth Gaussian-sum body grows directional bump
      // detail (lit-side bumps catch light, shadow-side bumps stay dark).
      const dqdx = sample(x_m + H_GRAD, z_m) - sample(x_m - H_GRAD, z_m)
      const dqdz = sample(x_m, z_m + H_GRAD) - sample(x_m, z_m - H_GRAD)
      const fxN = x_m * FBM_FREQ_FINE + 17.3
      const fzN = z_m * FBM_FREQ_FINE + 31.7
      const dnx = fbm3(fxN + NORMAL_EPS_M * FBM_FREQ_FINE, fzN) -
                  fbm3(fxN - NORMAL_EPS_M * FBM_FREQ_FINE, fzN)
      const dnz = fbm3(fxN, fzN + NORMAL_EPS_M * FBM_FREQ_FINE) -
                  fbm3(fxN, fzN - NORMAL_EPS_M * FBM_FREQ_FINE)
      let nx = -dqdx - dnx * NORMAL_NOISE_AMP
      let nz = -dqdz - dnz * NORMAL_NOISE_AMP
      const nlen = Math.hypot(nx, nz) || 1
      nx /= nlen; nz /= nlen

      // Diffuse: cloud surface lit by sun direction
      const diff = Math.max(0, nx * SUN_X + nz * SUN_Z)

      // Self-shadow: optical depth marching toward sun
      let depth = 0
      for (let k = 1; k <= SHADOW_SAMPLES; k++) {
        depth += sample(x_m + k * SHADOW_STEP_M * SUN_X,
                        z_m + k * SHADOW_STEP_M * SUN_Z)
      }
      const transmit = Math.exp(-depth * TRANSMIT_K)

      // Bottom AO: cumulus bases are darker; cloud above blocks light
      const above = sample(x_m, z_m + 200) + sample(x_m, z_m + 400)
      const baseLight = clamp01(1 - above * 1200)

      // Combine into a single luminance value. Big ambient floor keeps
      // cloud body bright (multiple-scattering proxy); direct diffuse
      // term swings the lit side toward HI. baseLight darkens undersides.
      const ambient = 0.55
      const direct = 0.45 * diff * (0.4 + 0.6 * transmit)
      const L = clamp01(ambient + direct - 0.30 * (1 - baseLight))
      const cloud = sampleRamp3(L)

      // Composite cloud over sky by alpha
      rgba[off]   = skyR + (cloud[0] - skyR) * alpha
      rgba[off+1] = skyG + (cloud[1] - skyG) * alpha
      rgba[off+2] = skyB + (cloud[2] - skyB) * alpha
      rgba[off+3] = 255
      off += 4
    }
  }

  drawForeground(rgba)
}

// --- Forcing schedule --------------------------------------------------

function fireCluster(simFrameCount) {
  // One fat thermal in the middle of the visible window. JS picks
  // x in world coords, the WASM does the actual perturbation.
  const xc_norm = 0.30 + Math.random() * 0.40   // 30%..70% of domain
  const xc_m = xc_norm * clouds.grid.widthM
  clouds.applyBubble(xc_m, 150, 4.0, 320)
}

// --- Hook --------------------------------------------------------------

export const CloudsCanvas = {
  async mounted() {
    try {
      await new Promise((r) => requestAnimationFrame(r))
      const canvas = this.el
      canvas.width = CANVAS_W
      canvas.height = CANVAS_H
      const ctx = canvas.getContext("2d")
      ctx.imageSmoothingEnabled = false

      await clouds.init()
      clouds.setWind(PRESEED_WIND)

      const rgba = new Uint8ClampedArray(CANVAS_W * CANVAS_H * 4)
      const qc = clouds.getQC()

      // Pre-seed: paint cumulus directly into the qc field at altitude.
      // The clouds are already there -- no surface convection. A few
      // sim steps after painting smooth the Gaussian sums via advection
      // without dissipating much.
      const NX = clouds.grid.NX, NZ = clouds.grid.NZ
      const DX = clouds.grid.DX, DZ = clouds.grid.DZ
      for (const c of PRESEED) {
        for (const lobe of LOBES) {
          paintGaussian(qc, NX, NZ, DX, DZ,
            c.cx + lobe.dx, c.cz + lobe.dz, lobe.sigma, lobe.peak)
        }
      }
      let simFrame = 0
      // Skip post-paint sim steps for now -- saturation adjustment will
      // evaporate freshly painted qc if qv isn't also raised.

      const onClick = (e) => {
        const rect = canvas.getBoundingClientRect()
        const fx = (e.clientX - rect.left) / rect.width
        const x_m = VIEW_X0 + fx * (VIEW_X1 - VIEW_X0)
        clouds.applyBubble(x_m, 150, 4.0, 320)
      }
      canvas.addEventListener("click", onClick)

      // Render the painted state once. The WASM saturation step would
      // evaporate freshly painted qc (subsaturated qv), so we don't step
      // here -- the scene is a fixed painting for now. Animation/drift
      // is the next iteration.
      renderFrame(rgba, qc)
      ctx.putImageData(new ImageData(rgba, CANVAS_W, CANVAS_H), 0, 0)

      let rafId = null

      this._stopLoop = () => {
        if (rafId !== null) cancelAnimationFrame(rafId)
        canvas.removeEventListener("click", onClick)
      }
    } catch (err) {
      console.error("[CloudsCanvas] mount failed:", err)
    }
  },

  destroyed() {
    if (this._stopLoop) this._stopLoop()
  },
}
