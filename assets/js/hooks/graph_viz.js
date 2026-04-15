export const GraphViz = {
  mounted() {
    this.engine = null;
    this.raf = null;
    this.ready = false;
    this.pendingGraph = null;
    this.pendingHighlight = null;
    this.pendingFocus = null;

    this.overlay = null;
    this.overlayCtx = null;
    this.histogramCanvas = null;
    this.histogramCtx = null;

    this.nodeIds = null;
    this.nodeLabels = null;
    this.pageranks = null;
    this.adjOffsets = null;
    this.adjNeighbors = null;
    this.walkers = null;
    this.visitCounts = null;
    this.totalVisits = 0;
    this.topHistIndices = null;

    this.primaryColor = "#ff8a28";
    this.contentColor = "#ffffff";

    this.handleEvent("render-graph", ({ data }) => {
      const binary = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
      if (this.ready) {
        this.engine.load_graph(binary);
        this.initWalkers();
        this.clearOverlay();
      } else {
        this.pendingGraph = binary;
      }
    });

    this.handleEvent("highlight-nodes", ({ node_ids }) => {
      if (!node_ids || node_ids.length === 0) return;
      if (this.ready) {
        this.engine.focus_node(node_ids[0]);
      } else {
        this.pendingHighlight = node_ids[0];
      }
    });

    this.handleEvent("focus-node", ({ id }) => {
      if (this.ready) {
        this.engine.focus_node(id);
      } else {
        this.pendingFocus = id;
      }
    });

    this.initBloom().catch((err) => {
      console.error("[GraphViz] init failed:", err);
    });
  },

  async initBloom() {
    console.log("[GraphViz] importing bloom wasm");
    const bloom = await import("/vendor/bloom/bloom.js");
    await bloom.default({ module_or_path: "/vendor/bloom/bloom_bg.wasm" });
    console.log("[GraphViz] wasm ready");

    const canvas = this.el;
    await waitForLayout(canvas);
    console.log("[GraphViz] canvas laid out", canvas.clientWidth, canvas.clientHeight);

    const dpr = window.devicePixelRatio || 1;
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;

    this.engine = new bloom.BloomEngine(canvas);
    console.log("[GraphViz] engine created, initializing renderer");
    await this.engine.init_renderer(canvas);
    console.log("[GraphViz] renderer ready");
    this.ready = true;

    this.initOverlay();
    this.initHistogram();

    if (this.pendingGraph) {
      console.log("[GraphViz] loading pending graph, bytes=", this.pendingGraph.length);
      this.engine.load_graph(this.pendingGraph);
      this.pendingGraph = null;
      console.log("[GraphViz] pending graph loaded");
      this.initWalkers();
    }
    if (this.pendingHighlight != null) {
      this.engine.focus_node(this.pendingHighlight);
      this.pendingHighlight = null;
    }
    if (this.pendingFocus != null) {
      this.engine.focus_node(this.pendingFocus);
      this.pendingFocus = null;
    }

    let last = performance.now();
    const loop = (now) => {
      const dt = (now - last) / 1000;
      last = now;
      this.engine.tick(dt);
      this.tickWalkers();
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);

    canvas.addEventListener("mousemove", (e) => {
      const rect = canvas.getBoundingClientRect();
      const ratio = window.devicePixelRatio || 1;
      const x = (e.clientX - rect.left) * ratio;
      const y = (e.clientY - rect.top) * ratio;
      this.hoveredNode = this.engine.hover(x, y);
    });

    canvas.addEventListener("click", () => {
      if (this.hoveredNode != null) {
        this.pushEvent("node_clicked", { id: this.hoveredNode });
      }
    });

    this.resizeObserver = new ResizeObserver(() => {
      const ratio = window.devicePixelRatio || 1;
      const w = canvas.clientWidth * ratio;
      const h = canvas.clientHeight * ratio;
      if (w === 0 || h === 0) return;
      canvas.width = w;
      canvas.height = h;
      this.engine.resize(w, h);
      this.resizeOverlay();
      this.resizeHistogram();
    });
    this.resizeObserver.observe(canvas);
  },

  initOverlay() {
    const overlay = document.getElementById("walker-overlay");
    if (!overlay) return;
    this.overlay = overlay;
    this.overlayCtx = overlay.getContext("2d");
    this.resizeOverlay();
  },

  resizeOverlay() {
    if (!this.overlay) return;
    const canvas = this.el;
    const dpr = window.devicePixelRatio || 1;
    this.overlay.width = canvas.clientWidth * dpr;
    this.overlay.height = canvas.clientHeight * dpr;
    this.overlay.style.width = canvas.clientWidth + "px";
    this.overlay.style.height = canvas.clientHeight + "px";
    this.clearOverlay();
  },

  clearOverlay() {
    if (!this.overlayCtx || !this.overlay) return;
    this.overlayCtx.clearRect(0, 0, this.overlay.width, this.overlay.height);
  },

  initHistogram() {
    if (this.histogramCanvas) return;
    const el = document.getElementById("walker-histogram");
    if (!el) return;
    this.histogramCanvas = el;
    this.histogramCtx = el.getContext("2d");
    this.resizeHistogram();
  },

  resizeHistogram() {
    const el = this.histogramCanvas;
    if (!el) return;
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(1, Math.floor(el.clientWidth * dpr));
    const h = Math.max(1, Math.floor(el.clientHeight * dpr));
    if (el.width !== w) el.width = w;
    if (el.height !== h) el.height = h;
  },

  initWalkers() {
    const ids = this.engine.node_ids();
    if (!ids || ids.length === 0) {
      this.nodeIds = null;
      this.walkers = null;
      return;
    }
    this.nodeIds = ids;
    this.nodeLabels = this.engine.node_labels();
    this.pageranks = this.engine.node_pageranks();
    this.adjOffsets = this.engine.adjacency_offsets();
    this.adjNeighbors = this.engine.adjacency_neighbors();

    const n = ids.length;
    const walkerCount = Math.min(200, Math.max(40, n));
    this.walkers = new Uint32Array(walkerCount);
    for (let i = 0; i < walkerCount; i++) {
      this.walkers[i] = (Math.random() * n) | 0;
    }
    this.visitCounts = new Float32Array(n);
    this.totalVisits = 0;

    const topK = Math.min(20, n);
    const order = Array.from({ length: n }, (_, i) => i);
    order.sort((a, b) => this.pageranks[b] - this.pageranks[a]);
    this.topHistIndices = order.slice(0, topK);
  },

  tickWalkers() {
    if (!this.walkers || !this.overlayCtx || !this.overlay) return;
    if (this.walkers.length === 0) return;
    if (!this.histogramCanvas) this.initHistogram();

    const positions = this.engine.node_screen_positions();
    if (!positions || positions.length === 0) return;

    const ctx = this.overlayCtx;
    const w = this.overlay.width;
    const h = this.overlay.height;

    ctx.globalCompositeOperation = "destination-out";
    ctx.fillStyle = "rgba(0, 0, 0, 0.08)";
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = "source-over";

    const offsets = this.adjOffsets;
    const neighbors = this.adjNeighbors;
    const n = this.nodeIds.length;
    const TELEPORT = 0.15;

    ctx.strokeStyle = this.primaryColor;
    ctx.globalAlpha = 0.55;
    ctx.lineWidth = 1.5;
    ctx.beginPath();

    for (let i = 0; i < this.walkers.length; i++) {
      const cur = this.walkers[i];
      let next;

      const outStart = offsets[cur];
      const outEnd = offsets[cur + 1];
      const outDeg = outEnd - outStart;

      if (outDeg === 0 || Math.random() < TELEPORT) {
        next = (Math.random() * n) | 0;
      } else {
        next = neighbors[outStart + ((Math.random() * outDeg) | 0)];
      }

      ctx.moveTo(positions[cur * 2], positions[cur * 2 + 1]);
      ctx.lineTo(positions[next * 2], positions[next * 2 + 1]);

      this.walkers[i] = next;
      this.visitCounts[next] += 1;
      this.totalVisits += 1;
    }
    ctx.stroke();

    ctx.globalAlpha = 1.0;
    ctx.fillStyle = this.primaryColor;
    for (let i = 0; i < this.walkers.length; i++) {
      const idx = this.walkers[i];
      ctx.beginPath();
      ctx.arc(positions[idx * 2], positions[idx * 2 + 1], 3, 0, Math.PI * 2);
      ctx.fill();
    }

    this.drawHistogram();
  },

  drawHistogram() {
    const ctx = this.histogramCtx;
    const canvas = this.histogramCanvas;
    if (!ctx || !canvas || !this.topHistIndices || this.totalVisits === 0) return;

    this.resizeHistogram();
    const w = canvas.width;
    const h = canvas.height;
    if (w < 4 || h < 4) return;
    ctx.clearRect(0, 0, w, h);

    const dpr = window.devicePixelRatio || 1;
    const padX = 8 * dpr;
    const padY = 8 * dpr;
    const rows = this.topHistIndices.length;
    const rowH = (h - padY * 2) / rows;
    const barH = Math.max(2 * dpr, rowH * 0.55);

    const labelW = Math.floor((w - padX * 2) * 0.48);
    const gap = 6 * dpr;
    const barX = padX + labelW + gap;
    const barAreaW = w - barX - padX;
    if (barAreaW < 10) return;

    const topPr = this.pageranks[this.topHistIndices[0]] || 1;
    const inv = 1 / this.totalVisits;

    const fontPx = Math.max(9 * dpr, Math.min(12 * dpr, rowH * 0.75));
    ctx.font = `${fontPx}px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`;
    ctx.textBaseline = "middle";

    for (let r = 0; r < rows; r++) {
      const idx = this.topHistIndices[r];
      const observed = this.visitCounts[idx] * inv;
      const target = this.pageranks[idx];

      const rowMid = padY + rowH * r + rowH / 2;
      const y = rowMid - barH / 2;
      const observedW = Math.min(1, observed / topPr) * barAreaW;
      const targetX = barX + Math.min(1, target / topPr) * barAreaW;

      const label = (this.nodeLabels && this.nodeLabels[idx]) || "";
      ctx.globalAlpha = 0.85;
      ctx.fillStyle = this.contentColor;
      ctx.textAlign = "right";
      ctx.fillText(
        truncateToWidth(ctx, label, labelW),
        padX + labelW,
        rowMid,
      );

      ctx.fillStyle = this.primaryColor;
      ctx.globalAlpha = 0.75;
      ctx.fillRect(barX, y, observedW, barH);

      ctx.globalAlpha = 0.9;
      ctx.strokeStyle = this.contentColor;
      ctx.lineWidth = 1 * dpr;
      ctx.beginPath();
      ctx.moveTo(targetX, y - 1 * dpr);
      ctx.lineTo(targetX, y + barH + 1 * dpr);
      ctx.stroke();
    }
    ctx.globalAlpha = 1.0;
  },

  destroyed() {
    if (this.raf) cancelAnimationFrame(this.raf);
    if (this.resizeObserver) this.resizeObserver.disconnect();
    if (this.engine) this.engine.free();
  },
};

function waitForLayout(el) {
  return new Promise((resolve) => {
    const check = () => {
      if (el.clientWidth > 0 && el.clientHeight > 0) {
        resolve();
      } else {
        requestAnimationFrame(check);
      }
    };
    check();
  });
}

function truncateToWidth(ctx, text, maxWidth) {
  if (!text) return "";
  if (ctx.measureText(text).width <= maxWidth) return text;
  const ellipsis = "…";
  let lo = 0;
  let hi = text.length;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (ctx.measureText(text.slice(0, mid) + ellipsis).width <= maxWidth) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo > 0 ? text.slice(0, lo) + ellipsis : ellipsis;
}
