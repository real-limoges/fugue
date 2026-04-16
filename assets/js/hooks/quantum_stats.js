// Three occupation histograms overlaid: Maxwell-Boltzmann, Bose-Einstein,
// Fermi-Dirac. Given N particles and L = 30 energy levels at ε_i = i, solve
// for the chemical potential μ that conserves N under each statistics, then
// plot n_i(T, μ). MB has a closed form. BE and FD use bisection — the sum
// Σ n_i(μ) is monotonic in μ, so bisection converges quickly.
//
// Y-axis is log-scaled. MB's exponential decay becomes a straight line
// spanning many levels instead of a dead column at the left, BE's spike
// compresses naturally, and FD's plateau-then-cliff is still legible with
// its tail extending below n=1 into the sub-unity region.

const LEVELS = 30;
const MB_COLOR = "rgba(203, 213, 225, 0.75)";
const QUANTUM_COLOR = "#22d3ee";
const AXIS_COLOR = "rgba(148, 163, 184, 0.35)";
const GRID_COLOR = "rgba(148, 163, 184, 0.12)";
const LABEL_COLOR = "rgba(148, 163, 184, 0.75)";
const Y_MIN = 0.01;

function energyLevels() {
  const e = new Float64Array(LEVELS);
  for (let i = 0; i < LEVELS; i++) e[i] = i;
  return e;
}

function sumOccupation(kind, energies, T, mu) {
  let sum = 0;
  for (const e of energies) {
    const x = (e - mu) / T;
    if (kind === "BE") {
      const d = Math.exp(x) - 1;
      if (d <= 0) return Infinity;
      sum += 1 / d;
    } else {
      sum += 1 / (Math.exp(x) + 1);
    }
  }
  return sum;
}

function solveMu(kind, energies, T, N) {
  if (kind === "MB") {
    let Z = 0;
    for (const e of energies) Z += Math.exp(-e / T);
    return T * Math.log(N / Z);
  }

  const e0 = energies[0];
  const eMax = energies[energies.length - 1];
  const scale = Math.max(T, 1);

  let lo, hi;
  if (kind === "BE") {
    lo = e0 - 200 * scale;
    // Strictly below the ground state, close enough that the boson
    // condensate can still be resolved at very low T.
    hi = e0 - 1e-12;
  } else {
    lo = e0 - 200 * scale;
    hi = eMax + 200 * scale;
  }

  for (let iter = 0; iter < 120; iter++) {
    const mid = (lo + hi) / 2;
    const s = sumOccupation(kind, energies, T, mid);
    if (s > N) hi = mid;
    else lo = mid;
    if (Math.abs(s - N) < 1e-6 * N) break;
  }
  return (lo + hi) / 2;
}

function occupation(kind, energies, T, mu) {
  const n = new Float64Array(energies.length);
  for (let i = 0; i < energies.length; i++) {
    const x = (energies[i] - mu) / T;
    if (kind === "MB") {
      n[i] = Math.exp(-x);
    } else if (kind === "BE") {
      const d = Math.exp(x) - 1;
      n[i] = d > 0 ? 1 / d : Infinity;
    } else {
      n[i] = 1 / (Math.exp(x) + 1);
    }
  }
  return n;
}

function drawCurve(ctx, pts) {
  ctx.beginPath();
  for (let i = 0; i < pts.length; i++) {
    const [x, y] = pts[i];
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function draw(canvas, T, N) {
  const ctx = canvas.getContext("2d");
  const dpr = window.devicePixelRatio || 1;
  const cssW = canvas.clientWidth;
  const cssH = canvas.clientHeight;
  if (canvas.width !== cssW * dpr || canvas.height !== cssH * dpr) {
    canvas.width = cssW * dpr;
    canvas.height = cssH * dpr;
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, cssW, cssH);

  const padL = 52;
  const padR = 20;
  const padT = 24;
  const padB = 44;
  const plotW = cssW - padL - padR;
  const plotH = cssH - padT - padB;

  const energies = energyLevels();

  const muMB = solveMu("MB", energies, T, N);
  const muBE = solveMu("BE", energies, T, N);
  const muFD = solveMu("FD", energies, T, N);

  const nMB = occupation("MB", energies, T, muMB);
  const nBE = occupation("BE", energies, T, muBE);
  const nFD = occupation("FD", energies, T, muFD);

  // Log y-axis. yMax is pinned to N (the physical maximum per-level
  // occupation, ignoring numerical bisection slop), rounded up to the next
  // power of 10 for clean tick labels. Keyed off N instead of maxN so the
  // axis doesn't jitter while dragging the temperature slider.
  const yMaxTarget = Math.max(N, 2);
  const yMax = Math.pow(10, Math.ceil(Math.log10(yMaxTarget * 1.05)));
  const logYMin = Math.log10(Y_MIN);
  const logYMax = Math.log10(yMax);
  const logSpan = logYMax - logYMin;

  const xToPx = (i) => padL + (i / (LEVELS - 1)) * plotW;
  const yToPx = (n) => {
    const clamped = Math.max(Y_MIN, Math.min(n, yMax));
    const lg = Math.log10(clamped);
    return padT + plotH - ((lg - logYMin) / logSpan) * plotH;
  };

  // Horizontal gridlines at each power of 10.
  ctx.strokeStyle = GRID_COLOR;
  ctx.lineWidth = 1;
  const firstPow = Math.ceil(logYMin);
  const lastPow = Math.floor(logYMax);
  for (let p = firstPow; p <= lastPow; p++) {
    const y = yToPx(Math.pow(10, p));
    ctx.beginPath();
    ctx.moveTo(padL, y);
    ctx.lineTo(padL + plotW, y);
    ctx.stroke();
  }

  // Axes
  ctx.strokeStyle = AXIS_COLOR;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(padL, padT);
  ctx.lineTo(padL, padT + plotH);
  ctx.lineTo(padL + plotW, padT + plotH);
  ctx.stroke();

  // Y-axis tick labels at each decade.
  ctx.fillStyle = LABEL_COLOR;
  ctx.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
  ctx.textAlign = "right";
  for (let p = firstPow; p <= lastPow; p++) {
    const value = Math.pow(10, p);
    const label = value >= 1 ? String(value) : value.toString();
    ctx.fillText(label, padL - 6, yToPx(value) + 3);
  }

  ctx.textAlign = "center";
  ctx.fillText("energy level →", padL + plotW / 2, padT + plotH + 28);
  ctx.textAlign = "left";
  ctx.fillText("0", padL, padT + plotH + 16);
  ctx.textAlign = "right";
  ctx.fillText(String(LEVELS - 1), padL + plotW, padT + plotH + 16);

  ctx.textAlign = "left";
  ctx.fillText("occupation (log) ↑", padL - 44, padT - 8);

  // Build polylines for each distribution
  const toPts = (arr) => {
    const out = new Array(LEVELS);
    for (let i = 0; i < LEVELS; i++) out[i] = [xToPx(i), yToPx(arr[i])];
    return out;
  };
  const mbPts = toPts(nMB);
  const bePts = toPts(nBE);
  const fdPts = toPts(nFD);

  // MB — classical baseline: gray dashed
  ctx.strokeStyle = MB_COLOR;
  ctx.lineWidth = 1.25;
  ctx.setLineDash([4, 4]);
  drawCurve(ctx, mbPts);
  ctx.setLineDash([]);

  // FD — thin cyan solid with dot markers at each level
  ctx.strokeStyle = QUANTUM_COLOR;
  ctx.lineWidth = 1.25;
  drawCurve(ctx, fdPts);
  ctx.fillStyle = QUANTUM_COLOR;
  for (let i = 0; i < LEVELS; i++) {
    const [x, y] = fdPts[i];
    ctx.beginPath();
    ctx.arc(x, y, 1.75, 0, 2 * Math.PI);
    ctx.fill();
  }

  // BE — thick cyan solid
  ctx.strokeStyle = QUANTUM_COLOR;
  ctx.lineWidth = 2.5;
  ctx.lineJoin = "round";
  drawCurve(ctx, bePts);

  // Legend
  ctx.font = "11px ui-sans-serif, system-ui, sans-serif";
  ctx.textAlign = "left";
  const lx = padL + plotW - 170;
  const ly = padT + 8;
  const lineLen = 24;
  const rowH = 16;

  // Bose-Einstein: thick cyan solid
  ctx.strokeStyle = QUANTUM_COLOR;
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(lx, ly + 6);
  ctx.lineTo(lx + lineLen, ly + 6);
  ctx.stroke();
  ctx.fillStyle = LABEL_COLOR;
  ctx.fillText("Bose–Einstein", lx + lineLen + 8, ly + 10);

  // Fermi-Dirac: thin cyan with dots
  ctx.strokeStyle = QUANTUM_COLOR;
  ctx.lineWidth = 1.25;
  ctx.beginPath();
  ctx.moveTo(lx, ly + rowH + 6);
  ctx.lineTo(lx + lineLen, ly + rowH + 6);
  ctx.stroke();
  ctx.fillStyle = QUANTUM_COLOR;
  for (let k = 0; k < 3; k++) {
    const dx = lx + 4 + k * ((lineLen - 8) / 2);
    ctx.beginPath();
    ctx.arc(dx, ly + rowH + 6, 1.75, 0, 2 * Math.PI);
    ctx.fill();
  }
  ctx.fillStyle = LABEL_COLOR;
  ctx.fillText("Fermi–Dirac", lx + lineLen + 8, ly + rowH + 10);

  // Maxwell-Boltzmann: gray dashed
  ctx.strokeStyle = MB_COLOR;
  ctx.lineWidth = 1.25;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.moveTo(lx, ly + rowH * 2 + 6);
  ctx.lineTo(lx + lineLen, ly + rowH * 2 + 6);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = LABEL_COLOR;
  ctx.fillText("Maxwell–Boltzmann", lx + lineLen + 8, ly + rowH * 2 + 10);
}

export const QuantumStats = {
  mounted() {
    this.logT = parseFloat(this.el.dataset.log_temperature);
    this.N = parseInt(this.el.dataset.particles, 10);
    this.render();

    this.handleEvent("quantum_stats:set_params", ({ log_temperature, particles }) => {
      this.logT = parseFloat(log_temperature);
      this.N = parseInt(particles, 10);
      this.render();
    });

    this.resizeObserver = new ResizeObserver(() => this.render());
    this.resizeObserver.observe(this.el);
  },

  destroyed() {
    if (this.resizeObserver) this.resizeObserver.disconnect();
  },

  render() {
    const T = Math.pow(10, this.logT);
    draw(this.el, T, this.N);
  },
};
