// @ts-check
// Calendar tooltip. Cells carry their numbers in `data-dims` and `data-mems`
// ("key=value;key=value"), and the container carries cluster names and
// colors once in `data-clusters`; this hook builds the hover card from them.
// The card used to be server-rendered into every cell, which made the first
// /mood diff about 5.8 MB (see FugueWeb.MoodLive.CalendarGrid).
// Right-anchored so the card clears the calendar even for far-right cells.

/**
 * @typedef {Record<string, {name: string, color: string}>} Clusters
 *
 * @typedef {object} State
 * @property {HTMLDivElement} tip
 * @property {(e: MouseEvent) => void} onEnter
 * @property {() => void} onLeave
 */

const MUTED = "color-mix(in oklch, var(--color-neutral-content) 65%, transparent)"

/** @param {string} s */
const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

/**
 * "a=1;b=2" -> [["a", "1"], ["b", "2"]]
 * @param {string | null} attr
 * @returns {Array<[string, string]>}
 */
const parsePairs = (attr) =>
  attr
    ? attr.split(";").map((pair) => {
        const at = pair.indexOf("=")
        return /** @type {[string, string]} */ ([pair.slice(0, at), pair.slice(at + 1)])
      })
    : []

/** @param {Array<[string, string]>} dims */
const dimensionsBlock = (dims) => {
  if (dims.length === 0) return ""
  const rows = dims
    .map(
      ([name, value]) =>
        `<span style="color: ${MUTED}">${escapeHtml(name)}</span><strong>${escapeHtml(value)}</strong>`
    )
    .join("")
  return `<div style="margin-top: 6px; display: grid; grid-template-columns: auto auto; gap: 1px 10px">${rows}</div>`
}

/**
 * @param {Array<[string, string]>} mems
 * @param {Clusters} clusters
 */
const membershipsBlock = (mems, clusters) => {
  if (mems.length === 0) return ""
  const rows = mems
    .map(([id, raw]) => {
      const weight = Number(raw)
      const name = escapeHtml(clusters[id]?.name ?? id)
      const color = escapeHtml(clusters[id]?.color ?? "#888")
      return (
        `<div style="display: flex; align-items: center; gap: 5px; margin: 2px 0">` +
        `<span style="color: ${color}; font-size: 11px; white-space: nowrap">${name}</span>` +
        `<div style="flex: 0 0 50px; height: 3px; background: color-mix(in oklch, var(--color-neutral-content) 10%, transparent); border-radius: 2px">` +
        `<div style="width: ${Math.round(weight * 50)}px; height: 3px; background: ${color}; border-radius: 2px"></div>` +
        `</div>` +
        `<span style="color: ${MUTED}; font-size: 10px; white-space: nowrap">${Math.round(weight * 100)}%</span>` +
        `</div>`
      )
    })
    .join("")
  return `<div style="margin-top: 6px; border-top: 1px solid color-mix(in oklch, var(--color-neutral-content) 12%, transparent); padding-top: 5px">${rows}</div>`
}

/**
 * The hover card for one day, from the cell's attribute values.
 * @param {{date: string, isGap: boolean, dims: string | null, mems: string | null}} day
 * @param {Clusters} clusters
 */
export const cardHtml = ({ date, isGap, dims, mems }, clusters) => {
  const gap = isGap
    ? `<br><span style="color: color-mix(in oklch, var(--color-neutral-content) 55%, transparent); font-style: italic">gap day</span>`
    : ""
  return (
    `<strong style="font-size: 13px">${escapeHtml(date)}</strong>` +
    gap +
    dimensionsBlock(parsePairs(dims)) +
    membershipsBlock(parsePairs(mems), clusters)
  )
}

/** @type {import("../types").LiveHook<State>} */
export const CalendarTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "tooltip-card tooltip-card--right"
    this.el.appendChild(this.tip)

    /** @param {MouseEvent} e */
    this.onEnter = (e) => {
      if (!(e.target instanceof Element)) return
      const cell = e.target.closest(".day-cell")
      if (!cell) return
      // Read on every hover rather than cached: the legend is tiny and this
      // stays right if a LiveView patch ever changes the cluster names.
      /** @type {Clusters} */
      const clusters = JSON.parse(this.el.getAttribute("data-clusters") ?? "{}")
      const day = {
        date: cell.getAttribute("data-date") ?? "",
        isGap: cell.classList.contains("is-gap"),
        dims: cell.getAttribute("data-dims"),
        mems: cell.getAttribute("data-mems"),
      }
      this.tip.innerHTML = cardHtml(day, clusters)
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

  // A LiveView patch to this container drops children the server didn't
  // render, which includes the card; put it back so hover keeps working
  // after a selection.
  updated() {
    if (!this.tip.isConnected) this.el.appendChild(this.tip)
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.onEnter)
    this.el.removeEventListener("mouseout", this.onLeave)
  },
}
