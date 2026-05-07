// Bayesian search demo: a grid of "rooms" with a probability heatmap of where
// the lost item is. Clicking a room searches it. If the item isn't there,
// that cell's probability collapses to zero and the rest renormalize.
//
// Receives the full grid + searched set + found flag from the LiveView via
// `bayes_search:state`. Click on a cell pushes `search_cell` back to the LV.

import { svgNS } from "./lab_chart";

const ROWS = 5;
const COLS = 5;
const CELL_GAP = 4;
const PADDING = 12;

// Color: dark base → site primary at higher probability. Linear ramp.
function probColor(p, maxP) {
  if (p <= 0) return "#1e1e24";
  const t = Math.min(1, p / Math.max(maxP, 1e-9));
  // dark → orange (mu axis color used elsewhere in /lab)
  const r = Math.round(30 + (255 - 30) * t);
  const g = Math.round(30 + (138 - 30) * t);
  const b = Math.round(36 + (40 - 36) * t);
  return `rgb(${r}, ${g}, ${b})`;
}

export const BayesSearch = {
  mounted() {
    this._grid = null;
    this._searched = new Set();
    this._found = null;

    this.handleEvent("bayes_search:state", ({ grid, searched, found }) => {
      this._grid = grid;
      this._searched = new Set(searched);
      this._found = found;
      this.render();
    });

    this.el.style.position = "relative";
    this.el.innerHTML = "";
    this.pushEvent("bayes_search:ready", {});
  },

  render() {
    if (!this._grid) return;
    const container = this.el;
    container.innerHTML = "";

    const W = container.clientWidth || 360;
    const H = W;
    const inner = W - 2 * PADDING;
    const cellW = (inner - CELL_GAP * (COLS - 1)) / COLS;
    const cellH = (inner - CELL_GAP * (ROWS - 1)) / ROWS;

    const maxP = Math.max(...this._grid);

    const svg = svgNS("svg", { width: W, height: H });

    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const i = r * COLS + c;
        const p = this._grid[i];
        const x = PADDING + c * (cellW + CELL_GAP);
        const y = PADDING + r * (cellH + CELL_GAP);
        const searched = this._searched.has(i);
        const isTruth = this._found === i;

        const rect = svgNS("rect", {
          x, y, width: cellW, height: cellH, rx: 4, ry: 4,
          fill: searched ? "#1e1e24" : probColor(p, maxP),
          stroke: isTruth ? "#ff8a28" : searched ? "#444" : "#000",
          "stroke-width": isTruth ? "2" : "1",
          style: this._found != null ? "cursor: default;" : "cursor: pointer;",
        });
        if (this._found == null) {
          rect.addEventListener("click", () => this.pushEvent("search_cell", { index: i }));
        }
        svg.appendChild(rect);

        // Probability label (small, monospace, only if non-trivial)
        if (!searched && p >= 0.005) {
          const txt = svgNS("text", {
            x: x + cellW / 2, y: y + cellH / 2 + 4,
            "text-anchor": "middle",
            fill: p / maxP > 0.6 ? "#1e1e24" : "#aaa",
            "font-size": "11", "font-family": "monospace",
          });
          txt.textContent = (p * 100).toFixed(0) + "%";
          svg.appendChild(txt);
        }

        if (isTruth) {
          const txt = svgNS("text", {
            x: x + cellW / 2, y: y + cellH / 2 + 4,
            "text-anchor": "middle", fill: "#ff8a28",
            "font-size": "13", "font-family": "monospace", "font-weight": "bold",
          });
          txt.textContent = "found";
          svg.appendChild(txt);
        } else if (searched) {
          const txt = svgNS("text", {
            x: x + cellW / 2, y: y + cellH / 2 + 4,
            "text-anchor": "middle", fill: "#666",
            "font-size": "11", "font-family": "monospace",
          });
          txt.textContent = "—";
          svg.appendChild(txt);
        }
      }
    }

    container.appendChild(svg);
  },
};
