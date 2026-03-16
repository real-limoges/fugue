const sims = {
  boids: {
    module: () => import("../vendor/petri/js/boids.js"),
    setup: async (m, w, h) => { await m.init(); m.start(2000, w, h); },
    loop: (m) => {
      m.step(1);
      if (Math.random() < 1 / 30) m.swapOne();
    },
  },
langton: {
    module: () => import("../vendor/petri/js/langton.js"),
    setup: async (m, w, h) => { await m.init(); m.start(8, w, h); },
    loop: (m) => m.step(500),
  },
  oscillators: {
    module: () => import("../vendor/petri/js/oscillators.js"),
    setup: async (m, w, h) => { await m.init(); m.start(w, h); },
    loop: (m) => m.step(2),
  },
};

// Read theme colors by sampling computed styles
function getThemeColors() {
  const root = document.documentElement;
  const theme = root.getAttribute("data-theme");

  // sample colors from a temp canvas to convert oklch → rgb
  const canvas = document.createElement("canvas");
  canvas.width = 1; canvas.height = 1;
  const ctx = canvas.getContext("2d");

  function resolve(oklchStr) {
    ctx.clearRect(0, 0, 1, 1);
    ctx.fillStyle = oklchStr;
    ctx.fillRect(0, 0, 1, 1);
    const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
    return [r, g, b];
  }

  // read CSS custom properties and resolve them
  const style = getComputedStyle(root);
  const baseProp = style.getPropertyValue("--color-base-100").trim();
  const primaryProp = style.getPropertyValue("--color-primary").trim();

  const base = baseProp ? resolve(baseProp) : [28, 19, 37];
  const primary = primaryProp ? resolve(primaryProp) : [200, 50, 180];

  return { base, primary };
}

let cachedColors = null;
let cachedRGBA = null;

function buildColorTable(base, primary) {
  const table = new Uint8Array(256 * 4);
  for (let i = 0; i < 256; i++) {
    const t = i / 255;
    const t2 = t * t;
    const offset = i * 4;
    table[offset]     = base[0] + Math.round((primary[0] - base[0]) * t2);
    table[offset + 1] = base[1] + Math.round((primary[1] - base[1]) * t2);
    table[offset + 2] = base[2] + Math.round((primary[2] - base[2]) * t2);
    table[offset + 3] = 255;
  }
  return table;
}

function refreshColors() {
  const colors = getThemeColors();
  const key = colors.base.join(",") + "|" + colors.primary.join(",");
  if (cachedColors !== key) {
    cachedColors = key;
    cachedRGBA = buildColorTable(colors.base, colors.primary);
  }
}

let cleanup = null;

export async function initSplash(canvasId, simName) {
  if (cleanup) { cleanup(); cleanup = null; }

  const sim = sims[simName];
  if (!sim) return null;

  const canvas = document.getElementById(canvasId);
  if (!canvas) return null;

  const canvasW = Math.min(window.innerWidth, 2560);
  const canvasH = Math.min(window.innerHeight, 1440);
  canvas.width = canvasW;
  canvas.height = canvasH;

  const ctx = canvas.getContext("2d");

  const mod = await sim.module();
  await sim.setup(mod, canvasW, canvasH);

  refreshColors();
  const pixelCount = canvasW * canvasH;
  const rgbaBuffer = new Uint8ClampedArray(pixelCount * 4);

  let rafId;
  let frameCount = 0;

  function loop() {
    sim.loop(mod);

    if (++frameCount % 120 === 0) refreshColors();

    const intensity = mod.getPixels();
    const lut = cachedRGBA;

    for (let i = 0; i < pixelCount; i++) {
      const lutOffset = intensity[i] * 4;
      const rgbaOffset = i * 4;
      rgbaBuffer[rgbaOffset]     = lut[lutOffset];
      rgbaBuffer[rgbaOffset + 1] = lut[lutOffset + 1];
      rgbaBuffer[rgbaOffset + 2] = lut[lutOffset + 2];
      rgbaBuffer[rgbaOffset + 3] = 255;
    }

    const imageData = new ImageData(rgbaBuffer, canvasW, canvasH);
    ctx.putImageData(imageData, 0, 0);
    rafId = requestAnimationFrame(loop);
  }
  rafId = requestAnimationFrame(loop);

  cleanup = () => cancelAnimationFrame(rafId);
  return cleanup;
}

export const simNames = Object.keys(sims);
