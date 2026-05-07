// Shared chart primitives + canonical dataset for /lab pages.

export const Z_95 = 1.96;

export const MARGIN = { top: 30, right: 45, bottom: 50, left: 60 };

export function linspace(a, b, n) {
  const step = (b - a) / (n - 1);
  return Array.from({ length: n }, (_, i) => a + i * step);
}

export function svgNS(tag, attrs = {}) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  return el;
}

export function polylinePath(xs, ys, scaleX, scaleY) {
  return xs.map((x, i) => `${i === 0 ? "M" : "L"}${scaleX(x)},${scaleY(ys[i])}`).join(" ");
}

export function bandPath(xs, lower, upper, scaleX, scaleY) {
  const top = xs.map((x, i) => `${i === 0 ? "M" : "L"}${scaleX(x)},${scaleY(upper[i])}`).join(" ");
  const bottom = [...xs]
    .reverse()
    .map((x, i) => {
      const j = xs.length - 1 - i;
      return `L${scaleX(x)},${scaleY(lower[j])}`;
    })
    .join(" ");
  return `${top} ${bottom} Z`;
}

export function formatTick(v) {
  if (Number.isInteger(v)) return String(v);
  return v.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
}

export async function loadGlissando() {
  const mod = await import("/vendor/glissando/glissando.js");
  await mod.default({ module_or_path: "/vendor/glissando/glissando_bg.wasm" });
  return mod.WasmGamlssModel;
}

// Builds an SVG with grid, axes, tick labels, and axis labels for the given config.
// Returns { svg, scaleX, scaleY, innerW, innerH, W, H } so callers can layer paths on top.
export function buildFrame({ container, xMin, xMax, yMin, yMax, xTicks, yTicks, xLabel, yLabel, xTickFormat, yTickFormat }) {
  const fmtX = xTickFormat || formatTick;
  const fmtY = yTickFormat || formatTick;
  const W = container.clientWidth || 700;
  const H = 420;
  const innerW = W - MARGIN.left - MARGIN.right;
  const innerH = H - MARGIN.top - MARGIN.bottom;

  const scaleX = (x) => MARGIN.left + ((x - xMin) / (xMax - xMin)) * innerW;
  const scaleY = (y) => MARGIN.top + innerH - ((y - yMin) / (yMax - yMin)) * innerH;

  const svg = svgNS("svg", { width: W, height: H });

  const gridG = svgNS("g", { opacity: "0.15" });
  for (const t of xTicks) {
    gridG.appendChild(svgNS("line", {
      x1: scaleX(t), y1: MARGIN.top, x2: scaleX(t), y2: MARGIN.top + innerH,
      stroke: "#fff", "stroke-width": "1",
    }));
  }
  for (const t of yTicks) {
    gridG.appendChild(svgNS("line", {
      x1: MARGIN.left, y1: scaleY(t), x2: MARGIN.left + innerW, y2: scaleY(t),
      stroke: "#fff", "stroke-width": "1",
    }));
  }
  svg.appendChild(gridG);

  svg.appendChild(svgNS("line", {
    x1: MARGIN.left, y1: MARGIN.top + innerH, x2: MARGIN.left + innerW, y2: MARGIN.top + innerH,
    stroke: "#555", "stroke-width": "1",
  }));
  svg.appendChild(svgNS("line", {
    x1: MARGIN.left, y1: MARGIN.top, x2: MARGIN.left, y2: MARGIN.top + innerH,
    stroke: "#555", "stroke-width": "1",
  }));

  for (const t of xTicks) {
    const node = svgNS("text", {
      x: scaleX(t), y: MARGIN.top + innerH + 18,
      "text-anchor": "middle", fill: "#888", "font-size": "11", "font-family": "monospace",
    });
    node.textContent = fmtX(t);
    svg.appendChild(node);
  }
  const xAxisLabel = svgNS("text", {
    x: MARGIN.left + innerW / 2, y: H - 4,
    "text-anchor": "middle", fill: "#666", "font-size": "12", "font-family": "monospace",
  });
  xAxisLabel.textContent = xLabel;
  svg.appendChild(xAxisLabel);

  for (const t of yTicks) {
    const node = svgNS("text", {
      x: MARGIN.left - 8, y: scaleY(t) + 4,
      "text-anchor": "end", fill: "#888", "font-size": "11", "font-family": "monospace",
    });
    node.textContent = fmtY(t);
    svg.appendChild(node);
  }
  const yAxisLabel = svgNS("text", {
    x: 12, y: MARGIN.top + innerH / 2,
    "text-anchor": "middle", fill: "#666", "font-size": "12", "font-family": "monospace",
    transform: `rotate(-90, 12, ${MARGIN.top + innerH / 2})`,
  });
  yAxisLabel.textContent = yLabel;
  svg.appendChild(yAxisLabel);

  return { svg, scaleX, scaleY, innerW, innerH, W, H };
}

export function buildScatter(data, scaleX, scaleY) {
  const g = svgNS("g");
  for (const [x, y] of data) {
    g.appendChild(svgNS("circle", {
      cx: scaleX(x), cy: scaleY(y), r: "3", fill: "#888", opacity: "0.65",
    }));
  }
  return g;
}
