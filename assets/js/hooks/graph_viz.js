import { Graph } from '@cosmos.gl/graph';

export const GraphViz = {
  mounted() {
    // Initialize Cosmograph
    this.graph = new Graph(this.el, {
      backgroundColor: '#0a0a1a',
      nodeColor: node => `rgb(${node.color[0]}, ${node.color[1]}, ${node.color[2]})`,
      nodeSize: node => node.size || 4,
      linkColor: '#ffffff11',
      linkWidth: 0.5,
      linkArrows: false,

      // Beautiful defaults
      simulation: {
        repulsion: 0.5,
        gravity: 0.2,
        linkSpring: 1.0,
        linkDistance: 2,
        friction: 0.85
      },

      // Rendering quality
      spaceSize: 8192,
      renderLinks: true,
      curvedLinks: false,

      // Interactions
      onClick: (node) => {
        if (node) {
          this.pushEvent("node_clicked", { id: node.id });
        }
      },

      // Hover effect
      onNodeMouseOver: (node) => {
        if (node) {
          this.graph.selectNode(node.id);
        }
      },

      // Performance
      pixelRatio: 2,
      scaleNodesOnZoom: true,

      // Initial view
      fitViewOnInit: true,
      fitViewDelay: 1000
    });

    // Listen for graph data from LiveView
    this.handleEvent("render-graph", ({ nodes, links }) => {
      console.log(`Rendering ${nodes.length} nodes, ${links.length} links`);
      this.graph.setData(nodes, links);
    });

    // Highlight nodes from search
    this.handleEvent("highlight-nodes", ({ node_ids }) => {
      this.graph.selectNodes(node_ids);

      // Auto-zoom to highlighted nodes
      if (node_ids.length > 0) {
        this.graph.fitView(node_ids, 1000);
      }
    });

    // Focus on specific node
    this.handleEvent("focus-node", ({ id }) => {
      this.graph.selectNode(id);
      this.graph.focusNode(id, 1000);
    });
  },

  destroyed() {
    if (this.graph) {
      this.graph.destroy();
    }
  }
};