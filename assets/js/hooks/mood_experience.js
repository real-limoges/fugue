import { DIMENSIONS, DIM_COLORS } from "./constants"

/** Ambient overlay and slide-out detail panel for day focus. */
export const MoodExperience = {
  mounted() {
    this.currentDay = null
    this.clusterColors = {}
    this.ambientEl = null
    this.panelEl = null

    // Create ambient overlay
    this.ambientEl = document.createElement("div")
    this.ambientEl.className = "mood-ambient"
    this.ambientEl.style.cssText = `
      position: fixed; inset: 0; pointer-events: none; z-index: 0;
      opacity: 0; transition: opacity 1.2s ease, background 1.5s ease;
    `
    document.body.appendChild(this.ambientEl)

    // Create detail panel
    this.panelEl = document.createElement("div")
    this.panelEl.className = "mood-day-panel"
    this.panelEl.style.cssText = `
      position: fixed; right: -380px; top: 0; bottom: 0; width: 360px;
      background: rgba(10, 10, 26, 0.95); border-left: 1px solid rgba(255,255,255,0.06);
      z-index: 50; padding: 20px; overflow-y: auto;
      transition: right 0.3s ease; backdrop-filter: blur(12px);
    `
    document.body.appendChild(this.panelEl)

    this.handleEvent("day-focus", ({ day }) => {
      if (day) {
        this.currentDay = day
        // Store cluster colors from day detail
        if (day.cluster_colors) this.clusterColors = day.cluster_colors
        this.showPanel(day)
        this.setAmbient(day)
      } else {
        this.currentDay = null
        this.hidePanel()
        this.clearAmbient()
      }
    })

    this.handleEvent("isolate-cluster", ({ cluster, clusterColors }) => {
      // Store colors whenever we get them
      if (clusterColors) this.clusterColors = clusterColors

      if (cluster && !this.currentDay) {
        this.setAmbientForCluster(cluster)
      } else if (!cluster && !this.currentDay) {
        this.clearAmbient()
      }
    })
  },

  // ── Panel ──────────────────────────────────

  showPanel(day) {
    const p = this.panelEl
    p.innerHTML = ""
    p.style.right = "0px"

    const hook = this

    // Close button
    const close = document.createElement("button")
    close.textContent = "×"
    close.style.cssText = `
      position: absolute; top: 12px; right: 16px; background: none; border: none;
      color: #666; font-size: 22px; cursor: pointer; line-height: 1;
    `
    close.onclick = () => hook.pushEvent("clear_highlights", {})
    p.appendChild(close)

    // Date heading
    const h = document.createElement("h3")
    h.style.cssText = "color: #ccc; font-size: 18px; font-weight: 700; margin-bottom: 4px;"
    h.textContent = day.date
    p.appendChild(h)

    // Dominant cluster
    if (day.dominant) {
      const dom = document.createElement("div")
      const color = (day.cluster_colors || {})[day.dominant.id] || "#888"
      dom.style.cssText = `color: ${color}; font-size: 13px; font-weight: 600; margin-bottom: 16px;`
      dom.textContent = day.dominant.name + " — " + (day.dominant.weight * 100).toFixed(0) + "% membership"
      p.appendChild(dom)
    }

    // Dimension bars
    const dimLabel = document.createElement("div")
    dimLabel.style.cssText = "color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;"
    dimLabel.textContent = "Dimensions"
    p.appendChild(dimLabel)

    DIMENSIONS.forEach(dim => {
      const val = (day.dimensions || {})[dim]
      if (val == null) return
      const color = DIM_COLORS[dim] || "#888"

      const row = document.createElement("div")
      row.style.cssText = "display: flex; align-items: center; gap: 8px; margin-bottom: 6px;"

      const label = document.createElement("span")
      label.style.cssText = `color: ${color}; font-size: 11px; width: 72px; font-weight: 500;`
      label.textContent = dim

      const barBg = document.createElement("div")
      barBg.style.cssText = "flex: 1; height: 6px; background: rgba(255,255,255,0.04); border-radius: 3px; position: relative;"

      const barFill = document.createElement("div")
      // Assume values are roughly 1-10 range; normalize
      const pct = Math.min(val / 10 * 100, 100)
      barFill.style.cssText = `width: ${pct}%; height: 100%; background: ${color}; border-radius: 3px; opacity: 0.7;`

      barBg.appendChild(barFill)

      const valSpan = document.createElement("span")
      valSpan.style.cssText = "color: #888; font-size: 11px; min-width: 20px; text-align: right;"
      valSpan.textContent = val

      row.appendChild(label)
      row.appendChild(barBg)
      row.appendChild(valSpan)
      p.appendChild(row)
    })

    // Memberships
    if (day.memberships && day.memberships.length > 0) {
      const memLabel = document.createElement("div")
      memLabel.style.cssText = "color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin: 16px 0 8px;"
      memLabel.textContent = "Cluster membership"
      p.appendChild(memLabel)

      day.memberships.forEach(m => {
        const color = (day.cluster_colors || {})[m.id] || "#888"
        const row = document.createElement("div")
        row.style.cssText = "display: flex; align-items: center; gap: 8px; margin-bottom: 4px; cursor: pointer;"
        row.onclick = () => hook.pushEvent("cluster_selected", { cluster: m.id })

        const dot = document.createElement("span")
        dot.style.cssText = `display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: ${color};`

        const name = document.createElement("span")
        name.style.cssText = `color: ${color}; font-size: 11px; flex: 1;`
        name.textContent = m.name

        const pct = document.createElement("span")
        pct.style.cssText = "color: #888; font-size: 11px;"
        pct.textContent = (m.weight * 100).toFixed(0) + "%"

        row.appendChild(dot)
        row.appendChild(name)
        row.appendChild(pct)
        p.appendChild(row)
      })
    }

    // Neighbors
    if (day.prev || day.next) {
      const nLabel = document.createElement("div")
      nLabel.style.cssText = "color: #666; font-size: 10px; text-transform: uppercase; letter-spacing: 1px; margin: 16px 0 8px;"
      nLabel.textContent = "Neighbors"
      p.appendChild(nLabel)

      const makeNeighbor = (label, n) => {
        if (!n) return
        const color = (day.cluster_colors || {})[n.dominant_id] || "#888"
        const row = document.createElement("div")
        row.style.cssText = "display: flex; align-items: center; gap: 8px; margin-bottom: 4px; cursor: pointer;"
        row.onclick = () => hook.pushEvent("day_selected", { date: n.date })

        const arrow = document.createElement("span")
        arrow.style.cssText = "color: #555; font-size: 11px; width: 14px;"
        arrow.textContent = label

        const date = document.createElement("span")
        date.style.cssText = "color: #999; font-size: 11px;"
        date.textContent = n.date

        const state = document.createElement("span")
        state.style.cssText = `color: ${color}; font-size: 11px; margin-left: auto;`
        state.textContent = n.dominant_name || ""

        row.appendChild(arrow)
        row.appendChild(date)
        row.appendChild(state)
        p.appendChild(row)
      }

      makeNeighbor("←", day.prev)
      makeNeighbor("→", day.next)
    }
  },

  hidePanel() {
    this.panelEl.style.right = "-380px"
  },

  // ── Ambient ────────────────────────────────

  setAmbient(day) {
    if (!day || !day.dominant) return
    const color = (day.cluster_colors || {})[day.dominant.id] || "#333"
    this.ambientEl.style.background = `radial-gradient(ellipse at 60% 40%, ${color}12 0%, transparent 70%)`
    this.ambientEl.style.opacity = "1"
  },

  setAmbientForCluster(clusterId) {
    const color = this.clusterColors[clusterId] || "#333"
    this.ambientEl.style.background = `radial-gradient(ellipse at 60% 40%, ${color}12 0%, transparent 70%)`
    this.ambientEl.style.opacity = "1"
  },

  clearAmbient() {
    this.ambientEl.style.opacity = "0"
  },

  destroyed() {
    if (this.ambientEl && this.ambientEl.parentNode) {
      this.ambientEl.parentNode.removeChild(this.ambientEl)
    }
    if (this.panelEl && this.panelEl.parentNode) {
      this.panelEl.parentNode.removeChild(this.panelEl)
    }
  }
}
