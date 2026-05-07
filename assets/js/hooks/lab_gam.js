// Multi-dataset GAM/GAMLSS lab via Glissando WASM.
//
// Each dataset declares three layers (linear / smooth-mean / smooth-mean+spread)
// fit with different distribution families. Layers are fit lazily on first
// dataset switch, then cached.

import {
  Z_95, linspace, svgNS, polylinePath, bandPath,
  loadGlissando, buildFrame, buildScatter,
} from "./lab_chart";

const GRID_N = 150;
const COLOR_LINE = "#ffffff";
const COLOR_SHAPE = "#aaaaaa";
const COLOR_SHAPE_SPREAD = "#ff8a28";

// ---- PRNG + sampling helpers (deterministic synthetic data) ---------------

function mulberry32(seed) {
  let s = seed >>> 0;
  return function () {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function makeNormal(rng) {
  return (mu, sigma) => {
    const u = rng() || 1e-9;
    const v = rng();
    return mu + sigma * Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  };
}

// ---- Data generators ------------------------------------------------------

function genHousePrice() {
  const rng = mulberry32(91);
  const N = makeNormal(rng);
  const data = [];
  for (let i = 0; i < 65; i++) {
    const sqft =
      600 + ((4500 - 600) * i) / 64 + (rng() - 0.5) * 80;
    // Price in $K; mildly concave-up — mean grows with size at an accelerating rate.
    const mean = 70 + 0.18 * sqft + 0.00006 * sqft * sqft;
    // CV climbs from ~0.10 (starter homes priced tightly) to ~0.30 (luxury, wildly variable).
    const cv = 0.1 + (0.2 * (sqft - 600)) / (4500 - 600);
    const sd = cv * mean;
    const y = Math.max(50, mean + N(0, sd));
    data.push([sqft, Math.round(y)]);
  }
  return data;
}

function genBayBridge() {
  const rng = mulberry32(42);
  const N = makeNormal(rng);
  const data = [];
  for (let day = 0; day < 4; day++) {
    for (let h = 5; h <= 22; h++) {
      // Two well-separated peaks (commute in ~8, commute home ~17.5).
      const truth =
        25 +
        220 * Math.exp(-((h - 8) * (h - 8)) / 3) +
        190 * Math.exp(-((h - 17.5) * (h - 17.5)) / 4);
      // NB-shaped variance: var = mu + mu^2 / k
      const k = 6;
      const sd = Math.sqrt(truth + (truth * truth) / k);
      const y = Math.max(0, Math.round(truth + N(0, sd)));
      data.push([h + (rng() - 0.5) * 0.3, y]);
    }
  }
  return data;
}

function genPizza() {
  const rng = mulberry32(13);
  const N = makeNormal(rng);
  const data = [];
  for (let i = 0; i < 60; i++) {
    const dist = 0.5 + (i / 59) * 8 + (rng() - 0.5) * 0.3;
    // Slight quadratic — fixed cooking baseline plus drive time + traffic.
    const truth = 12 + 3.2 * dist + 0.18 * dist * dist;
    data.push([dist, Math.max(6, truth + N(0, 2.5))]);
  }
  // Bidirectional outliers: lost driver, empty roads, GPS error, kitchen forgot.
  data.push([3.0, 78], [5.5, 12], [2.0, 65], [7.0, 18], [4.0, 70]);
  return data;
}

function genShotSuccess() {
  const rng = mulberry32(7);
  const N = makeNormal(rng);
  const data = [];
  for (let trial = 0; trial < 3; trial++) {
    for (let d = 0; d <= 40; d += 2) {
      // Sigmoidal decline: ~0.93 at the rim, ~0.06 at half-court.
      const truth = 0.05 + 0.9 / (1 + Math.exp((d - 18) / 5));
      const phi = 18;
      const sd = Math.sqrt((truth * (1 - truth)) / (1 + phi));
      const y = Math.max(0.005, Math.min(0.995, truth + N(0, sd)));
      data.push([d + (rng() - 0.5) * 0.5, y]);
    }
  }
  return data;
}

// ---- Band computation per family ------------------------------------------

// Symmetric ±Z·sigma. Used for Gaussian and StudentT (StudentT ignores nu —
// the t-quantile widening is small at our sample sizes and the visual lesson
// is about heavy-tailed likelihood, not band width).
function bandSymmetricSigma(pred) {
  return {
    lower: pred.mu.map((mu, i) => mu - Z_95 * pred.sigma[i]),
    upper: pred.mu.map((mu, i) => mu + Z_95 * pred.sigma[i]),
  };
}

function bandGammaCV(pred) {
  return {
    lower: pred.mu.map((mu, i) => mu - Z_95 * mu * pred.sigma[i]),
    upper: pred.mu.map((mu, i) => mu + Z_95 * mu * pred.sigma[i]),
  };
}

function bandPoisson(pred) {
  return {
    lower: pred.mu.map((mu) => Math.max(0, mu - Z_95 * Math.sqrt(mu))),
    upper: pred.mu.map((mu) => mu + Z_95 * Math.sqrt(mu)),
  };
}

function bandNB(pred) {
  return {
    lower: pred.mu.map((mu, i) =>
      Math.max(0, mu - Z_95 * Math.sqrt(mu + mu * mu * pred.sigma[i])),
    ),
    upper: pred.mu.map((mu, i) => mu + Z_95 * Math.sqrt(mu + mu * mu * pred.sigma[i])),
  };
}

function bandBeta(pred) {
  return {
    lower: pred.mu.map((mu, i) => {
      const sd = Math.sqrt((mu * (1 - mu)) / (1 + pred.phi[i]));
      return Math.max(0, mu - Z_95 * sd);
    }),
    upper: pred.mu.map((mu, i) => {
      const sd = Math.sqrt((mu * (1 - mu)) / (1 + pred.phi[i]));
      return Math.min(1, mu + Z_95 * sd);
    }),
  };
}

// ---- Formula helpers ------------------------------------------------------

const FAMILY_PARAMS = {
  Poisson: ["mu"],
  Gaussian: ["mu", "sigma"],
  Gamma: ["mu", "sigma"],
  NegativeBinomial: ["mu", "sigma"],
  StudentT: ["mu", "sigma", "nu"],
  Beta: ["mu", "phi"],
};

const SMOOTH_TERM = (col, n) => ({
  Smooth: { PSpline1D: { col_name: col, n_splines: n, degree: 3, penalty_order: 2 } },
});
const INTERCEPT = Object.freeze({ Intercept: null });

// Cap iterations so non-Gaussian fits don't grind for seconds chasing the
// last decimal. Curves are visually identical past ~50 outer iterations.
const FIT_CONFIG = JSON.stringify({ max_iterations: 80, tolerance: 0.005 });

// mode: "linear" (intercept + linear mu) | "smooth_mu" (smooth mu, intercept spread)
//     | "smooth_spread" (smooth mu, smooth spread parameter — sigma or phi)
function makeFormula(family, col, mode) {
  const params = FAMILY_PARAMS[family];
  const muTerms =
    mode === "linear"
      ? [INTERCEPT, { Linear: { col_name: col } }]
      : mode === "smooth_mu" || mode === "smooth_spread"
        ? [SMOOTH_TERM(col, 10)]
        : (() => {
            throw new Error(`unknown formula mode: ${mode}`);
          })();

  const result = { mu: muTerms };
  for (const p of params) {
    if (p === "mu") continue;
    if (mode === "smooth_spread" && (p === "sigma" || p === "phi")) {
      result[p] = [SMOOTH_TERM(col, 6)];
    } else {
      result[p] = [INTERCEPT];
    }
  }
  return JSON.stringify(result);
}

// ---- Dataset registry -----------------------------------------------------

const DATASETS = {
  house_price: {
    xCol: "sqft",
    xLabel: "Floor area (sqft)",
    yLabel: "Price ($1000s)",
    xMin: 500, xMax: 4700, yMin: 0, yMax: 3400,
    xTicks: [500, 1500, 2500, 3500, 4500],
    yTicks: [0, 500, 1000, 1500, 2000, 2500, 3000],
    data: genHousePrice,
    layers: [
      { id: "linear", color: COLOR_LINE, dashed: true, family: "Gaussian", formula: makeFormula("Gaussian", "sqft", "linear") },
      { id: "gam", color: COLOR_SHAPE, family: "Gaussian", formula: makeFormula("Gaussian", "sqft", "smooth_mu"), bandFn: bandSymmetricSigma },
      { id: "gamlss", color: COLOR_SHAPE_SPREAD, family: "Gamma", formula: makeFormula("Gamma", "sqft", "smooth_spread"), bandFn: bandGammaCV },
    ],
  },

  bay_bridge: {
    xCol: "hour",
    xLabel: "Hour of day",
    yLabel: "Cars per minute",
    xMin: 5, xMax: 22, yMin: 0, yMax: 320,
    xTicks: [6, 9, 12, 15, 18, 21],
    yTicks: [0, 50, 100, 150, 200, 250, 300],
    data: genBayBridge,
    layers: [
      { id: "linear", color: COLOR_LINE, dashed: true, family: "Poisson", formula: makeFormula("Poisson", "hour", "linear") },
      { id: "gam", color: COLOR_SHAPE, family: "Poisson", formula: makeFormula("Poisson", "hour", "smooth_mu"), bandFn: bandPoisson },
      { id: "gamlss", color: COLOR_SHAPE_SPREAD, family: "NegativeBinomial", formula: makeFormula("NegativeBinomial", "hour", "smooth_spread"), bandFn: bandNB },
    ],
  },

  pizza: {
    xCol: "dist",
    xLabel: "Distance (miles)",
    yLabel: "Delivery time (min)",
    xMin: 0, xMax: 9, yMin: 0, yMax: 90,
    xTicks: [0, 2, 4, 6, 8],
    yTicks: [0, 20, 40, 60, 80],
    data: genPizza,
    layers: [
      { id: "linear", color: COLOR_LINE, dashed: true, family: "Gaussian", formula: makeFormula("Gaussian", "dist", "linear") },
      { id: "gam", color: COLOR_SHAPE, family: "Gaussian", formula: makeFormula("Gaussian", "dist", "smooth_spread"), bandFn: bandSymmetricSigma },
      { id: "gamlss", color: COLOR_SHAPE_SPREAD, family: "StudentT", formula: makeFormula("StudentT", "dist", "smooth_spread"), bandFn: bandSymmetricSigma },
    ],
  },

  shot_success: {
    xCol: "dist",
    xLabel: "Distance from basket (ft)",
    yLabel: "Shot success rate",
    xMin: 0, xMax: 42, yMin: -0.05, yMax: 1.1,
    xTicks: [0, 5, 10, 15, 20, 25, 30, 35, 40],
    yTicks: [0, 0.25, 0.5, 0.75, 1.0],
    yTickFormat: (v) => `${Math.round(v * 100)}%`,
    data: genShotSuccess,
    layers: [
      { id: "linear", color: COLOR_LINE, dashed: true, family: "Gaussian", formula: makeFormula("Gaussian", "dist", "linear") },
      { id: "gam", color: COLOR_SHAPE, family: "Gaussian", formula: makeFormula("Gaussian", "dist", "smooth_spread"), bandFn: bandSymmetricSigma },
      { id: "gamlss", color: COLOR_SHAPE_SPREAD, family: "Beta", formula: makeFormula("Beta", "dist", "smooth_spread"), bandFn: bandBeta },
    ],
  },
};

// ---- Hook -----------------------------------------------------------------

// Wait for one paint plus a macrotask, so the browser has time to render
// status text and process any queued user events before the next blocking fit.
function yieldToBrowser() {
  return new Promise((resolve) => {
    requestAnimationFrame(() => setTimeout(resolve, 0));
  });
}

export const LabGam = {
  async mounted() {
    this._wasm = null;
    this._cache = {};
    this._layers = { linear: false, gam: false, gamlss: false };
    this._destroyed = false;
    this._pending = null;
    this._currentId = null;

    const container = this.el;
    container.style.position = "relative";
    container.innerHTML = "";
    const loading = document.createElement("div");
    loading.textContent = "Loading…";
    loading.style.cssText = "color:#888;font-size:13px;padding:12px;font-family:monospace";
    container.appendChild(loading);
    this._loading = loading;

    this.handleEvent("lab_gam:set_dataset", ({ dataset_id, layers }) => {
      this._layers = layers || this._layers;
      this.switchDataset(dataset_id);
    });

    this.handleEvent("lab_gam:set_layers", ({ layers }) => {
      this._layers = layers;
      this.applyLayers();
    });

    // Server replies with the current dataset_id + layers; keeps the JS hook
    // in sync after a LiveView reconnect, where server-side layer_state
    // survives but `_layers` here would otherwise reinitialize blank.
    this.pushEvent("lab_gam:ready", {});

    try {
      this._wasm = await loadGlissando();
      if (this._destroyed) return;

      // Pre-fit every dataset now, yielding between fits so the page stays
      // interactive. Each WASM fit blocks the main thread for a beat;
      // doing it on click made dataset switches feel like a freeze.
      const initial = this._pending || container.dataset.datasetId || "house_price";
      const order = [initial, ...Object.keys(DATASETS).filter((k) => k !== initial)];

      for (let i = 0; i < order.length; i++) {
        if (this._destroyed) return;
        const id = order[i];
        this.showStatus(`Fitting (${i + 1}/${order.length})…`);
        await yieldToBrowser();
        if (this._destroyed) return;

        try {
          this._cache[id] = this.fitDataset(id);
        } catch (err) {
          console.error(`[LabGam] fit failed for ${id}:`, err);
        }

        // Render the first dataset as soon as it's ready so the user has
        // something to look at while the rest of the cache warms up.
        if (i === 0 && this._cache[id]) {
          this.hideStatus();
          const target = this._pending || id;
          this._pending = null;
          this.switchDataset(target);
        } else if (this._pending && this._cache[this._pending]) {
          const target = this._pending;
          this._pending = null;
          this.switchDataset(target);
        }
      }

      this.hideStatus();
      if (this._pending) {
        const target = this._pending;
        this._pending = null;
        this.switchDataset(target);
      }
    } catch (err) {
      this.showError(err);
    }
  },

  destroyed() {
    this._destroyed = true;
  },

  showError(err) {
    if (this._loading) {
      this._loading.textContent = `Error: ${err.message}`;
      this._loading.style.color = "#f88";
    }
    console.error("[LabGam]", err);
  },

  showStatus(text) {
    if (this._loading) {
      this._loading.textContent = text;
      if (!this._loading.parentNode) this.el.appendChild(this._loading);
    }
  },

  hideStatus() {
    if (this._loading && this._loading.parentNode) {
      this._loading.parentNode.removeChild(this._loading);
    }
  },

  switchDataset(id) {
    if (!DATASETS[id]) {
      this.showError(new Error(`unknown dataset: ${id}`));
      return;
    }

    // Cache miss = mount() hasn't fit this dataset yet (WASM still loading,
    // or pre-fit hasn't reached this id). Remember the target; the pre-fit
    // loop will pick it up the moment the cache is populated.
    if (!this._cache[id]) {
      this._pending = id;
      this.showStatus("Fitting…");
      return;
    }

    this._currentId = id;
    this.hideStatus();
    this.renderDataset(id);
    this.applyLayers();
  },

  fitDataset(id) {
    const cfg = DATASETS[id];
    const data = cfg.data();
    const xs = data.map((d) => d[0]);
    const ys = data.map((d) => d[1]);
    const yJson = JSON.stringify(ys);
    const dataJson = JSON.stringify({ [cfg.xCol]: xs });
    const gridXs = linspace(cfg.xMin, cfg.xMax, GRID_N);
    const gridJson = JSON.stringify({ [cfg.xCol]: gridXs });

    const layerFits = {};
    for (const layer of cfg.layers) {
      const model = this._wasm.fitWithConfig(yJson, dataJson, layer.formula, layer.family, FIT_CONFIG);
      const pred = JSON.parse(model.predict(gridJson));
      const fit = { mu: pred.mu };
      if (layer.bandFn) {
        const band = layer.bandFn(pred);
        fit.lower = band.lower;
        fit.upper = band.upper;
      }
      layerFits[layer.id] = fit;
    }
    return { data, gridXs, layerFits };
  },

  renderDataset(id) {
    const cfg = DATASETS[id];
    const cached = this._cache[id];
    const container = this.el;

    for (const child of [...container.children]) {
      if (child !== this._loading) container.removeChild(child);
    }

    const { svg, scaleX, scaleY } = buildFrame({ container, ...cfg });
    const scatterG = buildScatter(cached.data, scaleX, scaleY);
    svg.appendChild(scatterG);

    for (const layer of cfg.layers) {
      const fit = cached.layerFits[layer.id];
      const g = svgNS("g", { id: `lab-gam-layer-${layer.id}` });
      if (fit.lower && fit.upper) {
        g.appendChild(svgNS("path", {
          d: bandPath(cached.gridXs, fit.lower, fit.upper, scaleX, scaleY),
          fill: layer.color, opacity: "0.13",
        }));
      }
      const lineAttrs = {
        d: polylinePath(cached.gridXs, fit.mu, scaleX, scaleY),
        stroke: layer.color, "stroke-width": layer.dashed ? "1.5" : "2",
        fill: "none", opacity: layer.dashed ? "0.55" : "1",
      };
      if (layer.dashed) lineAttrs["stroke-dasharray"] = "6,3";
      g.appendChild(svgNS("path", lineAttrs));
      svg.appendChild(g);
    }

    svg.appendChild(scatterG);
    container.appendChild(svg);
    this._svg = svg;
  },

  // Layer ids are fixed across all datasets — every dataset declares exactly
  // these three slots. Toggle state in the LiveView mirrors this.
  applyLayers() {
    if (!this._svg) return;
    for (const id of ["linear", "gam", "gamlss"]) {
      const el = this._svg.getElementById(`lab-gam-layer-${id}`);
      if (el) el.style.display = this._layers[id] ? "" : "none";
    }
  },
};
