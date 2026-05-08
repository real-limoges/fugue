// Calendar tooltip: server-rendered HTML in `data-tooltip` on each cell.
// JS only positions and shows/hides; right-anchored so the tooltip clears
// the calendar surface even when the cell is on the far right edge.
export const CalendarTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "tooltip-card tooltip-card--right"
    this.el.appendChild(this.tip)

    this.onEnter = (e) => {
      const cell = e.target.closest(".day-cell")
      if (!cell) return
      const html = cell.getAttribute("data-tooltip")
      if (!html) return
      this.tip.innerHTML = html
      const r = this.el.getBoundingClientRect()
      this.tip.style.top = e.clientY - r.top - 10 + "px"
      this.tip.style.opacity = "1"
    }
    this.onLeave = () => {
      this.tip.style.opacity = "0"
    }

    this.el.addEventListener("mouseover", this.onEnter)
    this.el.addEventListener("mouseout", this.onLeave)
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.onEnter)
    this.el.removeEventListener("mouseout", this.onLeave)
  },
}
