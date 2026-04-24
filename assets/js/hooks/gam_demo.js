// Reaction time vs. age — three-layer GAM demo using Glissando WASM.
// Layer 1: linear Gaussian regression (baseline)
// Layer 2: Gaussian GAM — nonlinear mean, flat confidence band (constant σ)
// Layer 3: Gamma GAMLSS — nonlinear mean, widening band (σ grows with age)

const DATA = [
  [10,283],[11,275],[12,291],[14,268],[15,253],[17,262],[18,248],[19,244],
  [20,228],[21,222],[22,218],[23,215],[24,213],[25,217],[26,221],[27,219],[28,224],[29,227],
  [30,220],[32,228],[33,235],[35,240],[36,238],[38,247],[39,252],
  [40,248],[42,255],[43,260],[45,270],[46,258],[48,278],[49,285],
  [50,272],[52,280],[53,295],[55,303],[56,285],[57,310],[59,318],
  [60,312],[62,332],[63,318],[65,355],[66,340],[68,372],[69,358],
  [70,368],[72,385],[73,410],[75,428],[76,405],[78,448],[79,435],
  [80,455],[81,475],[82,498],
];

const GRID_N = 150;
const AGE_MIN = 10;
const AGE_MAX = 82;
const RT_MIN = 160;
const RT_MAX = 520;

const MARGIN = { top: 30, right: 45, bottom: 50, left: 60 };

const COLOR_GAM    = "#aaaaaa";  // Gaussian — gray
const COLOR_GAMLSS = "#ff8a28";  // Gamma — site orange

const LINEAR_FORMULA = JSON.stringify({
  mu: [{ Intercept: null }, { Linear: { col_name: "age" } }],
  sigma: [{ Intercept: null }],
});

const GAM_FORMULA = JSON.stringify({
  mu: [{ Smooth: { PSpline1D: { col_name: "age", n_splines: 15, degree: 3, penalty_order: 2 } } }],
  sigma: [{ Intercept: null }],
});

const GAMLSS_FORMULA = JSON.stringify({
  mu: [{ Smooth: { PSpline1D: { col_name: "age", n_splines: 15, degree: 3, penalty_order: 2 } } }],
  sigma: [{ Smooth: { PSpline1D: { col_name: "age", n_splines: 10, degree: 3, penalty_order: 2 } } }],
});

function linspace(a, b, n) {
  const step = (b - a) / (n - 1);
  return Array.from({ length: n }, (_, i) => a + i * step);
}

function svgNS(tag, attrs = {}) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  return el;
}

function polylinePath(xs, ys, scaleX, scaleY) {
  return xs.map((x, i) => `${i === 0 ? "M" : "L"}${scaleX(x)},${scaleY(ys[i])}`).join(" ");
}

function bandPath(xs, lower, upper, scaleX, scaleY) {
  const top = xs.map((x, i) => `${i === 0 ? "M" : "L"}${scaleX(x)},${scaleY(upper[i])}`).join(" ");
  const bottom = [...xs].reverse().map((x, i) => {
    const j = xs.length - 1 - i;
    return `L${scaleX(x)},${scaleY(lower[j])}`;
  }).join(" ");
  return `${top} ${bottom} Z`;
}

export const GamDemo = {
  async mounted() {
    this.layers = { linear: false, gam: false, gamlss: false };

    const container = this.el;
    container.style.position = "relative";
    const loading = document.createElement("div");
    loading.textContent = "Fitting models…";
    loading.style.cssText = "color:#888;font-size:13px;padding:12px;font-family:monospace";
    container.appendChild(loading);

    this.handleEvent("gam:set_layers", (layers) => {
      this.layers = layers;
      this.applyLayers();
    });

    try {
      const mod = await import("/vendor/glissando/glissando.js");
      await mod.default({ module_or_path: "/vendor/glissando/glissando_bg.wasm" });
      const { WasmGamlssModel } = mod;

      const ages = DATA.map(d => d[0]);
      const rts  = DATA.map(d => d[1]);
      const yJson    = JSON.stringify(rts);
      const dataJson = JSON.stringify({ age: ages });

      const gridAges = linspace(AGE_MIN, AGE_MAX, GRID_N);
      const gridJson = JSON.stringify({ age: gridAges });

      const linearModel = WasmGamlssModel.fit(yJson, dataJson, LINEAR_FORMULA, "Gaussian");
      const gamModel    = WasmGamlssModel.fit(yJson, dataJson, GAM_FORMULA,    "Gaussian");
      const gamlssModel = WasmGamlssModel.fit(yJson, dataJson, GAMLSS_FORMULA, "Gamma");

      const linearPred = JSON.parse(linearModel.predict(gridJson));
      const gamPred    = JSON.parse(gamModel.predict(gridJson));
      const gamlssPred = JSON.parse(gamlssModel.predict(gridJson));

      // Gaussian band: mu ± 1.96σ, where σ is constant (intercept-only sigma model)
      const gamBandLower  = gamPred.mu.map((mu, i) => mu - 1.96 * gamPred.sigma[i]);
      const gamBandUpper  = gamPred.mu.map((mu, i) => mu + 1.96 * gamPred.sigma[i]);

      // Gamma band: mu ± 1.96·mu·σ, where σ is the CV (grows with age)
      const gamlssBandLower = gamlssPred.mu.map((mu, i) => mu - 1.96 * mu * gamlssPred.sigma[i]);
      const gamlssBandUpper = gamlssPred.mu.map((mu, i) => mu + 1.96 * mu * gamlssPred.sigma[i]);

      container.removeChild(loading);
      this.buildSvg(
        container, gridAges,
        linearPred.mu,
        gamPred.mu,    gamBandLower,    gamBandUpper,
        gamlssPred.mu, gamlssBandLower, gamlssBandUpper,
      );
      this.applyLayers();
    } catch (err) {
      loading.textContent = `Error: ${err.message}`;
      console.error("[GamDemo]", err);
    }
  },

  buildSvg(container, gridAges, linearMu, gamMu, gamBandLower, gamBandUpper, gamlssMu, gamlssBandLower, gamlssBandUpper) {
    const W = container.clientWidth || 700;
    const H = 420;
    const innerW = W - MARGIN.left - MARGIN.right;
    const innerH = H - MARGIN.top - MARGIN.bottom;

    const scaleX = age => MARGIN.left + (age - AGE_MIN) / (AGE_MAX - AGE_MIN) * innerW;
    const scaleY = rt  => MARGIN.top + innerH - (rt - RT_MIN) / (RT_MAX - RT_MIN) * innerH;

    const svg = svgNS("svg", { width: W, height: H });

    // Grid lines
    const xTicks = [10, 20, 30, 40, 50, 60, 70, 80];
    const yTicks = [200, 250, 300, 350, 400, 450, 500];
    const gridG = svgNS("g", { opacity: "0.15" });
    for (const age of xTicks) {
      gridG.appendChild(svgNS("line", {
        x1: scaleX(age), y1: MARGIN.top, x2: scaleX(age), y2: MARGIN.top + innerH,
        stroke: "#fff", "stroke-width": "1"
      }));
    }
    for (const rt of yTicks) {
      gridG.appendChild(svgNS("line", {
        x1: MARGIN.left, y1: scaleY(rt), x2: MARGIN.left + innerW, y2: scaleY(rt),
        stroke: "#fff", "stroke-width": "1"
      }));
    }
    svg.appendChild(gridG);

    // Axes
    svg.appendChild(svgNS("line", {
      x1: MARGIN.left, y1: MARGIN.top + innerH, x2: MARGIN.left + innerW, y2: MARGIN.top + innerH,
      stroke: "#555", "stroke-width": "1"
    }));
    svg.appendChild(svgNS("line", {
      x1: MARGIN.left, y1: MARGIN.top, x2: MARGIN.left, y2: MARGIN.top + innerH,
      stroke: "#555", "stroke-width": "1"
    }));

    // X axis labels
    for (const age of xTicks) {
      const t = svgNS("text", {
        x: scaleX(age), y: MARGIN.top + innerH + 18,
        "text-anchor": "middle", fill: "#888", "font-size": "11", "font-family": "monospace"
      });
      t.textContent = age;
      svg.appendChild(t);
    }
    const xLabel = svgNS("text", {
      x: MARGIN.left + innerW / 2, y: H - 4,
      "text-anchor": "middle", fill: "#666", "font-size": "12", "font-family": "monospace"
    });
    xLabel.textContent = "Age";
    svg.appendChild(xLabel);

    // Y axis labels
    for (const rt of yTicks) {
      const t = svgNS("text", {
        x: MARGIN.left - 8, y: scaleY(rt) + 4,
        "text-anchor": "end", fill: "#888", "font-size": "11", "font-family": "monospace"
      });
      t.textContent = rt;
      svg.appendChild(t);
    }
    const yLabel = svgNS("text", {
      x: 12, y: MARGIN.top + innerH / 2,
      "text-anchor": "middle", fill: "#666", "font-size": "12", "font-family": "monospace",
      transform: `rotate(-90, 12, ${MARGIN.top + innerH / 2})`
    });
    yLabel.textContent = "Reaction time (ms)";
    svg.appendChild(yLabel);

    // Scatter
    const scatterG = svgNS("g");
    for (const [age, rt] of DATA) {
      scatterG.appendChild(svgNS("circle", {
        cx: scaleX(age), cy: scaleY(rt), r: "3",
        fill: "#888", opacity: "0.65"
      }));
    }
    svg.appendChild(scatterG);

    // Draw order (back to front): Gaussian band → Gamma band → Gamma line → Gaussian line → Linear line → dots
    // Gaussian band drawn first so Gamma band overlaps it at the edges — the contrast is the point

    // Layer: Gaussian GAM — flat band + gray line
    const gamG = svgNS("g", { id: "gam-layer-gam" });
    gamG.appendChild(svgNS("path", {
      d: bandPath(gridAges, gamBandLower, gamBandUpper, scaleX, scaleY),
      fill: COLOR_GAM, opacity: "0.12"
    }));
    gamG.appendChild(svgNS("path", {
      d: polylinePath(gridAges, gamMu, scaleX, scaleY),
      stroke: COLOR_GAM, "stroke-width": "2", fill: "none"
    }));
    svg.appendChild(gamG);

    // Layer: Gamma GAMLSS — widening band + orange line
    const gamlssG = svgNS("g", { id: "gam-layer-gamlss" });
    gamlssG.appendChild(svgNS("path", {
      d: bandPath(gridAges, gamlssBandLower, gamlssBandUpper, scaleX, scaleY),
      fill: COLOR_GAMLSS, opacity: "0.15"
    }));
    gamlssG.appendChild(svgNS("path", {
      d: polylinePath(gridAges, gamlssMu, scaleX, scaleY),
      stroke: COLOR_GAMLSS, "stroke-width": "2", fill: "none"
    }));
    svg.appendChild(gamlssG);

    // Layer: Linear regression — white dashed, no band
    const linearG = svgNS("g", { id: "gam-layer-linear" });
    linearG.appendChild(svgNS("path", {
      d: polylinePath(gridAges, linearMu, scaleX, scaleY),
      stroke: "#ffffff", "stroke-width": "1.5", "stroke-dasharray": "6,3", fill: "none", opacity: "0.5"
    }));
    svg.appendChild(linearG);

    // Redraw scatter on top so dots sit above the bands
    svg.appendChild(scatterG);

    container.appendChild(svg);
    this._svg = svg;
  },

  applyLayers() {
    if (!this._svg) return;
    const map = { linear: "gam-layer-linear", gam: "gam-layer-gam", gamlss: "gam-layer-gamlss" };
    for (const [key, id] of Object.entries(map)) {
      const el = this._svg.getElementById(id);
      if (el) el.style.display = this.layers[key] ? "" : "none";
    }
  },

  destroyed() {},
};
