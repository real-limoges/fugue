// @ts-check
// Guided spotlight tour over the /mood page.
// Dims the page via a box-shadow trick, walks through 5 chapters,
// and finishing it skips the intro, the same way the Skip button does.
// Styles are in assets/css/mood_tour.css.

import { requireElement } from "../lib/dom.js"

const STEPS = [
  {
    id: "mood-chapter-1",
    title: "Here are my states",
    body: "The fuzzy clustering found these on its own; no labels given. Each one is a shape my days tend to fall into, more gravity well than box.",
  },
  {
    id: "mood-chapter-2",
    title: "Every day, laid out",
    body: "One square per day. Color is the dominant state, brightness is how hard it pulled. Drag across the strip to zoom into any window.",
  },
  {
    id: "mood-chapter-3",
    title: "How they shift",
    body: "States don't change at random. Thicker paths mean a well-trodden route from one to another.",
  },
  {
    id: "mood-chapter-5",
    title: "And where I missed",
    body: "I'm not perfect at this. A lot of the time the state I came back in wasn't the one I left in; that's its own kind of signal.",
  },
  {
    id: "mood-param-controls",
    title: "Poke the math yourself",
    body: "The algorithm has knobs. Open this drawer to tune k and m and watch the whole page recompute.",
  },
]

/**
 * A part of the card that buildCard wrote.
 * @param {HTMLElement} card
 * @param {string} selector
 */
const cardPart = (card, selector) => requireElement(card, selector, HTMLElement)

/** @typedef {(typeof STEPS)[number]} Step */

/**
 * @typedef {object} State
 * @property {number} index current step, -1 before the first
 * @property {boolean} active
 * @property {HTMLElement | null} currentTarget the spotlit element
 * @property {number | undefined} spotlightTimer pending spotlight, cancelled on step change
 * @property {HTMLDivElement | null} card
 * @property {(e: MouseEvent) => void} clickHandler
 * @property {(e: KeyboardEvent) => void} keyHandler
 */

/**
 * @typedef {object} Methods
 * @property {() => void} buildCard
 * @property {() => void} teardownCard
 * @property {() => void} clearSpotlight
 * @property {() => void} start
 * @property {() => void} next
 * @property {() => void} prev
 * @property {(step: Step) => void} apply
 * @property {() => void} finish
 * @property {() => void} cancel
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const MoodTour = {
  mounted() {
    this.index = -1
    this.active = false
    this.currentTarget = null
    this.spotlightTimer = undefined
    this.card = null

    /** @param {MouseEvent} e */
    this.clickHandler = (e) => {
      if (e.target instanceof Element && e.target.closest("[data-start-tour]")) {
        e.preventDefault()
        this.start()
      }
    }
    document.addEventListener("click", this.clickHandler)

    /** @param {KeyboardEvent} e */
    this.keyHandler = (e) => {
      if (!this.active) return
      if (e.key === "Escape") {
        e.preventDefault()
        this.cancel()
      } else if (e.key === "ArrowRight" || e.key === "Enter") {
        e.preventDefault()
        this.next()
      } else if (e.key === "ArrowLeft") {
        e.preventDefault()
        this.prev()
      }
    }
    document.addEventListener("keydown", this.keyHandler)
  },

  destroyed() {
    this.clearSpotlight()
    this.teardownCard()
    if (this.clickHandler) document.removeEventListener("click", this.clickHandler)
    if (this.keyHandler) document.removeEventListener("keydown", this.keyHandler)
  },

  buildCard() {
    if (this.card) return
    this.card = document.createElement("div")
    this.card.id = "mood-tour-card"
    this.card.setAttribute("role", "dialog")
    this.card.setAttribute("aria-live", "polite")
    this.card.innerHTML = `
      <div class="tour-title" data-tour-title></div>
      <div class="tour-body" data-tour-body></div>
      <div class="tour-controls">
        <span class="tour-counter" data-tour-counter></span>
        <div class="tour-right">
          <button type="button" data-tour-action="cancel">Exit</button>
          <button type="button" data-tour-action="prev">Back</button>
          <button type="button" data-tour-primary data-tour-action="next">Next &rsaquo;</button>
        </div>
      </div>
    `
    document.body.appendChild(this.card)
    this.card.addEventListener("click", (e) => {
      if (!(e.target instanceof Element)) return
      const btn = e.target.closest("[data-tour-action]")
      if (!btn) return
      const action = btn.getAttribute("data-tour-action")
      if (action === "next") this.next()
      else if (action === "prev") this.prev()
      else if (action === "cancel") this.cancel()
    })
  },

  teardownCard() {
    if (this.card && this.card.parentNode) this.card.parentNode.removeChild(this.card)
    this.card = null
  },

  clearSpotlight() {
    // A step change inside the 260ms scroll wait would otherwise let the old
    // timer spotlight the step being left, and nothing would ever clear it.
    clearTimeout(this.spotlightTimer)
    this.spotlightTimer = undefined
    if (this.currentTarget) {
      this.currentTarget.classList.remove("mood-tour-spotlight")
      this.currentTarget = null
    }
  },

  start() {
    if (this.active) return
    this.active = true
    this.index = -1
    this.buildCard()
    this.next()
  },

  next() {
    this.clearSpotlight()
    this.index += 1
    if (this.index >= STEPS.length) {
      this.finish()
      return
    }
    this.apply(STEPS[this.index])
  },

  prev() {
    if (this.index <= 0) return
    this.clearSpotlight()
    this.index -= 1
    this.apply(STEPS[this.index])
  },

  apply(step) {
    const card = this.card
    if (!card) return

    const target = document.getElementById(step.id)
    if (!target) {
      this.next()
      return
    }
    // <details> targets: open them so the spotlight highlights actual content
    if (target instanceof HTMLDetailsElement && !target.open) target.open = true

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    // Wait for the smooth scroll to settle before applying the shadow,
    // otherwise the dim layer shifts mid-animation.
    this.spotlightTimer = window.setTimeout(() => {
      target.classList.add("mood-tour-spotlight")
      this.currentTarget = target
    }, 260)

    cardPart(card, "[data-tour-title]").textContent = step.title
    cardPart(card, "[data-tour-body]").textContent = step.body
    cardPart(card, "[data-tour-counter]").textContent = `${this.index + 1} / ${STEPS.length}`

    cardPart(card, "[data-tour-primary]").innerHTML =
      this.index === STEPS.length - 1 ? "Done" : "Next &rsaquo;"

    cardPart(card, '[data-tour-action="prev"]').style.visibility =
      this.index === 0 ? "hidden" : "visible"
  },

  finish() {
    this.clearSpotlight()
    this.teardownCard()
    this.active = false
    // Finishing the tour skips the intro, exactly as the Skip button does:
    // run that button's own command rather than a copy of it.
    const skip = requireElement(document, "#mood-skip-intro", HTMLButtonElement)
    this.js().exec(skip.getAttribute("phx-click") ?? "")
  },

  cancel() {
    this.clearSpotlight()
    this.teardownCard()
    this.active = false
  },
}
