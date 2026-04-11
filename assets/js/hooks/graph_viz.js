export const GraphViz = {
  mounted() {
    this.engine = null;
    this.raf = null;
    this.initBloom();
  },

  async initBloom() {
    const bloom = await import("/vendor/bloom/bloom.js");
    await bloom.default("/vendor/bloom/bloom_bg.wasm");

    const canvas = this.el;
    canvas.width = canvas.clientWidth * (window.devicePixelRatio || 1);
    canvas.height = canvas.clientHeight * (window.devicePixelRatio || 1);

    this.engine = new bloom.BloomEngine(canvas);
    await this.engine.init_renderer(canvas);

    let last = performance.now();
    const loop = (now) => {
      this.engine.tick((now - last) / 1000);
      last = now;
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);

    this.handleEvent("render-graph", ({ data }) => {
      const binary = Uint8Array.from(atob(data), c => c.charCodeAt(0));
      this.engine.load_graph(binary);
    });

    this.handleEvent("highlight-nodes", ({ node_ids }) => {
      // TODO: bloom doesn't expose batch highlight yet —
      // for now focus on the first match
      if (node_ids.length > 0) {
        this.engine.focus_node(node_ids[0]);
      }
    });

    this.handleEvent("focus-node", ({ id }) => {
      this.engine.focus_node(id);
    });

    // Forward hover/click to LiveView
    canvas.addEventListener("mousemove", (e) => {
      const rect = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      const x = (e.clientX - rect.left) * dpr;
      const y = (e.clientY - rect.top) * dpr;
      this.hoveredNode = this.engine.hover(x, y);
    });

    canvas.addEventListener("click", () => {
      if (this.hoveredNode != null) {
        this.pushEvent("node_clicked", { id: this.hoveredNode });
      }
    });

    // Handle resize
    this.resizeObserver = new ResizeObserver(() => {
      const dpr = window.devicePixelRatio || 1;
      canvas.width = canvas.clientWidth * dpr;
      canvas.height = canvas.clientHeight * dpr;
      this.engine.resize(canvas.width, canvas.height);
    });
    this.resizeObserver.observe(canvas);
  },

  destroyed() {
    if (this.raf) cancelAnimationFrame(this.raf);
    if (this.resizeObserver) this.resizeObserver.disconnect();
    if (this.engine) this.engine.free();
  }
};
