// Posterior-based decision: same Gamma posterior as the rate demo, plus a
// threshold. Shaded area to the right of the threshold = P(rate > threshold).
//
// `bayes_decision:state` payload:
//   { post_alpha, post_beta, threshold, x_max }

import { svgNS, linspace, polylinePath, buildFrame, MARGIN } from "./lab_chart";

const GRID_N = 400;
const COLOR_POSTERIOR = "#ff8a28";

function gammaLogPdf(xs, alpha, beta) {
  return xs.map((x) => (x <= 0 ? -Infinity : (alpha - 1) * Math.log(x) - beta * x));
}

function gammaDensity(xs, alpha, beta) {
  const dx = xs[1] - xs[0];
  const max = Math.max(...gammaLogPdf(xs, alpha, beta).filter(Number.isFinite));
  const raw = gammaLogPdf(xs, alpha, beta).map((lp) =>
    Number.isFinite(lp) ? Math.exp(lp - max) : 0,
  );
  const area = raw.reduce((a, b) => a + b, 0) * dx;
  return raw.map((r) => r / area);
}

// Rectangle-rule approximation of P(X > threshold) given a normalized density
// on a uniform grid.
function tailProbability(xs, pdf, threshold) {
  const dx = xs[1] - xs[0];
  let p = 0;
  for (let i = 0; i < xs.length; i++) {
    if (xs[i] >= threshold) p += pdf[i] * dx;
  }
  return Math.max(0, Math.min(1, p));
}

export const BayesDecision = {
  mounted() {
    this._state = null;
    this.handleEvent("bayes_decision:state", (state) => {
      this._state = state;
      this.render();
    });
    this.el.innerHTML = "";
    this.pushEvent("bayes_decision:ready", {});
  },

  render() {
    if (!this._state) return;
    const { post_alpha, post_beta, threshold, x_max } = this._state;
    const container = this.el;
    container.innerHTML = "";

    const xs = linspace(0.001, x_max, GRID_N);
    const pdf = gammaDensity(xs, post_alpha, post_beta);
    const yMax = Math.max(...pdf) * 1.08;
    const tailP = tailProbability(xs, pdf, threshold);

    const xTicks = linspace(0, x_max, 7).map((v) => Math.round(v * 10) / 10);

    const { svg, scaleX, scaleY, innerH } = buildFrame({
      container,
      xMin: 0, xMax: x_max, yMin: 0, yMax,
      xTicks, yTicks: [],
      xLabel: "Rate (events / year)",
      yLabel: "Density",
    });

    // Shaded tail (right of threshold)
    const tailXs = xs.filter((x) => x >= threshold);
    if (tailXs.length > 0) {
      const tailYs = tailXs.map((_, i) => pdf[xs.length - tailXs.length + i]);
      const points = [
        `M${scaleX(threshold)},${scaleY(0)}`,
        ...tailXs.map((x, i) => `L${scaleX(x)},${scaleY(tailYs[i])}`),
        `L${scaleX(tailXs[tailXs.length - 1])},${scaleY(0)}`,
        "Z",
      ].join(" ");
      svg.appendChild(svgNS("path", {
        d: points, fill: COLOR_POSTERIOR, opacity: "0.32",
      }));
    }

    // Posterior curve
    svg.appendChild(svgNS("path", {
      d: polylinePath(xs, pdf, scaleX, scaleY),
      stroke: COLOR_POSTERIOR, "stroke-width": "2", fill: "none",
    }));

    // Threshold line
    svg.appendChild(svgNS("line", {
      x1: scaleX(threshold), y1: scaleY(0),
      x2: scaleX(threshold), y2: scaleY(yMax),
      stroke: "#fff", "stroke-width": "1.5", opacity: "0.6",
      "stroke-dasharray": "5,3",
    }));

    // Probability readout (top-right)
    const readout = svgNS("text", {
      x: MARGIN.left + (svg.getAttribute("width") - MARGIN.left - MARGIN.right) - 8,
      y: MARGIN.top + 18,
      "text-anchor": "end", fill: COLOR_POSTERIOR,
      "font-size": "16", "font-family": "monospace", "font-weight": "bold",
    });
    readout.textContent = `P(rate > ${threshold.toFixed(1)}) = ${(tailP * 100).toFixed(1)}%`;
    svg.appendChild(readout);

    container.appendChild(svg);
  },
};
