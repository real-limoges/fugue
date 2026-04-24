/** Generic hover tooltip: positions a floating div near the cursor whose
 *  content is pulled from a `data-tooltip` attribute (raw HTML) on any
 *  descendant. Used by views whose tooltip content is pre-rendered server-side. */
export const HoverTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "hover-tooltip"
    this.tip.style.cssText = `
      position: absolute; pointer-events: none;
      background: rgba(10,10,26,0.92); color: #eee;
      padding: 10px 14px; border-radius: 8px;
      border: 1px solid rgba(255,255,255,0.06);
      box-shadow: 0 4px 16px rgba(0,0,0,0.4);
      font-size: 12px; line-height: 1.5; white-space: nowrap;
      z-index: 100; opacity: 0; transition: opacity 0.1s;
    `
    this.el.appendChild(this.tip)

    this.onOver = (e) => {
      const target = e.target.closest("[data-tooltip]")
      if (!target) return
      const html = target.getAttribute("data-tooltip")
      if (!html) return
      this.tip.innerHTML = html
      this.position(e)
      this.tip.style.opacity = "1"
    }
    this.onMove = (e) => {
      if (this.tip.style.opacity === "1") this.position(e)
    }
    this.onOut = (e) => {
      const to = e.relatedTarget?.closest?.("[data-tooltip]")
      if (!to) this.tip.style.opacity = "0"
    }

    this.el.addEventListener("mouseover", this.onOver)
    this.el.addEventListener("mousemove", this.onMove)
    this.el.addEventListener("mouseout", this.onOut)
  },

  position(e) {
    const r = this.el.getBoundingClientRect()
    this.tip.style.top = (e.clientY - r.top + 12) + "px"
    this.tip.style.left = Math.min(e.clientX - r.left + 12, r.width - 220) + "px"
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.onOver)
    this.el.removeEventListener("mousemove", this.onMove)
    this.el.removeEventListener("mouseout", this.onOut)
  }
}
