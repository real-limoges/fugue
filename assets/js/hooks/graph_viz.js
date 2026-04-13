export const GraphViz = {
  mounted() {
    this.engine = null;
    this.raf = null;
    this.ready = false;
    this.pendingGraph = null;
    this.pendingHighlight = null;
    this.pendingFocus = null;

    // Register server->client handlers synchronously so events fired
    // during async WASM/WebGPU init aren't dropped.
    this.handleEvent("render-graph", ({ data }) => {
      const binary = Uint8Array.from(atob(data), c => c.charCodeAt(0));
      if (this.ready) {
        this.engine.load_graph(binary);
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

    if (this.pendingGraph) {
      console.log("[GraphViz] loading pending graph, bytes=", this.pendingGraph.length);
      this.engine.load_graph(this.pendingGraph);
      this.pendingGraph = null;
      console.log("[GraphViz] pending graph loaded");
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
      this.engine.tick((now - last) / 1000);
      last = now;
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
    });
    this.resizeObserver.observe(canvas);
  },

  destroyed() {
    if (this.raf) cancelAnimationFrame(this.raf);
    if (this.resizeObserver) this.resizeObserver.disconnect();
    if (this.engine) this.engine.free();
  }
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
