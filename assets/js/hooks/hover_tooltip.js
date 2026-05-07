// Generic hover tooltip: positions a floating div near the cursor whose
// content comes from a `data-tooltip` attribute on any descendant. Content
// is rendered server-side; the hook just positions and shows/hides.
export const HoverTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "tooltip-card"
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
