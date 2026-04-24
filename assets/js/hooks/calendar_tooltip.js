/** Micro-hook: renders a floating tooltip for calendar cells.
 *  Per-cell data is pre-shipped as JSON in `data-day`; position follows cursor Y. */
export const CalendarTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "calendar-tooltip"
    this.tip.style.cssText = `
      position: absolute; right: 0; pointer-events: none;
      background: rgba(10,10,26,0.92); color: #eee;
      padding: 10px 14px; border-radius: 8px;
      border: 1px solid rgba(255,255,255,0.06);
      box-shadow: 0 4px 16px rgba(0,0,0,0.4);
      font-size: 12px; line-height: 1.5; white-space: nowrap;
      z-index: 100; opacity: 0; transition: opacity 0.1s;
    `
    this.el.appendChild(this.tip)

    this.onEnter = (e) => {
      const rect = e.target.closest(".day-cell")
      if (!rect) return
      const raw = rect.getAttribute("data-day")
      if (!raw) return
      let day
      try { day = JSON.parse(raw) } catch { return }
      this.tip.innerHTML = this.buildHtml(day)
      const containerRect = this.el.getBoundingClientRect()
      this.tip.style.top = (e.clientY - containerRect.top - 10) + "px"
      this.tip.style.opacity = "1"
    }
    this.onLeave = () => { this.tip.style.opacity = "0" }

    this.el.addEventListener("mouseover", this.onEnter)
    this.el.addEventListener("mouseout", this.onLeave)
  },

  buildHtml(day) {
    let html = `<strong style="font-size:13px">${day.date}</strong>`
    if (day.isGap) html += `<br><span style="color:#666;font-style:italic">gap day</span>`

    if (day.dimensions) {
      html += `<div style="margin-top:6px; display:grid; grid-template-columns:auto auto; gap:1px 10px">`
      for (const [k, v] of Object.entries(day.dimensions)) {
        html += `<span style="color:#888">${k}</span><strong>${v}</strong>`
      }
      html += `</div>`
    }

    if (day.memberships && day.memberships.length > 0) {
      html += `<div style="margin-top:6px; border-top:1px solid rgba(255,255,255,0.08); padding-top:5px">`
      for (const m of day.memberships) {
        const pct = (m.weight * 100).toFixed(0)
        const barW = Math.round(m.weight * 50)
        html += `<div style="display:flex; align-items:center; gap:5px; margin:2px 0">
          <span style="color:${m.color}; font-size:11px; white-space:nowrap">${m.name}</span>
          <div style="flex:0 0 50px; height:3px; background:rgba(255,255,255,0.06); border-radius:2px">
            <div style="width:${barW}px; height:3px; background:${m.color}; border-radius:2px"></div>
          </div>
          <span style="color:#888; font-size:10px; white-space:nowrap">${pct}%</span>
        </div>`
      }
      html += `</div>`
    }
    return html
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.onEnter)
    this.el.removeEventListener("mouseout", this.onLeave)
  }
}
