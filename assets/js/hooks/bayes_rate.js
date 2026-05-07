// Gamma posterior over a Poisson rate. Receives prior and posterior shape +
// rate parameters from the LiveView and draws both densities on one chart.
//
// `bayes_rate:state` payload:
//   { prior_alpha, prior_beta, post_alpha, post_beta, x_max }

import { svgNS, linspace, polylinePath, buildFrame } from "./lab_chart";

const GRID_N = 250;
const COLOR_PRIOR = "#888888";
const COLOR_POSTERIOR = "#ff8a28";

// Log-density of Gamma(alpha, beta) at xs (with xs > 0). Unnormalized;
// caller normalizes numerically over the grid for stability with large alpha.
function gammaLogPdf(xs, alpha, beta) {
  return xs.map((x) => (x <= 0 ? -Infinity : (alpha - 1) * Math.log(x) - beta * x));
}

function normalizeDensity(logPdf, dx) {
  const max = Math.max(...logPdf.filter(Number.isFinite));
  const raw = logPdf.map((lp) => (Number.isFinite(lp) ? Math.exp(lp - max) : 0));
  const area = raw.reduce((a, b) => a + b, 0) * dx;
  return raw.map((r) => r / area);
}

function gammaDensity(xs, alpha, beta) {
  const dx = xs[1] - xs[0];
  return normalizeDensity(gammaLogPdf(xs, alpha, beta), dx);
}

export const BayesRate = {
  mounted() {
    this._state = null;
    this.handleEvent("bayes_rate:state", (state) => {
      this._state = state;
      this.render();
    });
    this.el.innerHTML = "";
    this.pushEvent("bayes_rate:ready", {});
  },

  render() {
    if (!this._state) return;
    const { prior_alpha, prior_beta, post_alpha, post_beta, x_max } = this._state;
    const container = this.el;
    container.innerHTML = "";

    const xs = linspace(0.001, x_max, GRID_N);
    const priorPdf = gammaDensity(xs, prior_alpha, prior_beta);
    const postPdf = gammaDensity(xs, post_alpha, post_beta);
    const yMax = Math.max(...priorPdf, ...postPdf) * 1.08;

    const xTicks = linspace(0, x_max, 7).map((v) => Math.round(v * 10) / 10);

    const { svg, scaleX, scaleY } = buildFrame({
      container,
      xMin: 0, xMax: x_max, yMin: 0, yMax,
      xTicks, yTicks: [],
      xLabel: "Rate (events / year)",
      yLabel: "Density",
    });

    // Prior (dim)
    svg.appendChild(svgNS("path", {
      d: polylinePath(xs, priorPdf, scaleX, scaleY),
      stroke: COLOR_PRIOR, "stroke-width": "1.5", fill: "none",
      opacity: "0.5", "stroke-dasharray": "5,3",
    }));

    // Posterior (bright)
    svg.appendChild(svgNS("path", {
      d: polylinePath(xs, postPdf, scaleX, scaleY),
      stroke: COLOR_POSTERIOR, "stroke-width": "2", fill: "none",
    }));

    // Posterior mean marker
    const postMean = post_alpha / post_beta;
    if (postMean > 0 && postMean < x_max) {
      svg.appendChild(svgNS("line", {
        x1: scaleX(postMean), y1: scaleY(0),
        x2: scaleX(postMean), y2: scaleY(yMax * 0.92),
        stroke: COLOR_POSTERIOR, "stroke-width": "1", opacity: "0.4",
        "stroke-dasharray": "3,3",
      }));
      const txt = svgNS("text", {
        x: scaleX(postMean), y: scaleY(yMax * 0.94) - 4,
        "text-anchor": "middle", fill: COLOR_POSTERIOR,
        "font-size": "11", "font-family": "monospace",
      });
      txt.textContent = `mean ${postMean.toFixed(2)}`;
      svg.appendChild(txt);
    }

    container.appendChild(svg);
  },
};
