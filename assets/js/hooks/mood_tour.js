// Guided spotlight tour over the /mood page.
// Dims the page via a box-shadow trick, walks through 5 chapters,
// completion sets the mood-skip-intro flag so the preamble collapses.

const FLAG_KEY = "mood-skip-intro"

const STEPS = [
  {
    id: "mood-chapter-1",
    title: "Here are my states",
    body: "The fuzzy clustering found these on its own — no labels given. Each one is a shape my days tend to fall into, more gravity well than box.",
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
    body: "I'm not perfect at this. A lot of the time the state I came back in wasn't the one I left in — that's its own kind of signal.",
  },
  {
    id: "mood-param-controls",
    title: "Poke the math yourself",
    body: "The algorithm has knobs. Open this drawer to tune k and m and watch the whole page recompute.",
  },
]

const STYLES = `
  .mood-tour-spotlight {
    position: relative;
    z-index: 60;
    border-radius: 8px;
    box-shadow:
      0 0 0 6px rgba(255, 255, 255, 0.08),
      0 0 0 9999px rgba(0, 0, 0, 0.78);
    transition: box-shadow 240ms ease-out;
  }
  #mood-tour-card {
    position: fixed;
    left: 50%;
    bottom: 2rem;
    transform: translateX(-50%);
    z-index: 99999;
    width: min(92vw, 34rem);
    background: #0d0d0d;
    color: #e5e7eb;
    border: 1px solid #2a2a2a;
    border-radius: 10px;
    padding: 1rem 1.1rem 0.9rem;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    pointer-events: auto;
    font-size: 0.85rem;
    line-height: 1.5;
  }
  #mood-tour-card .tour-title {
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: #9ca3af;
    margin-bottom: 0.35rem;
  }
  #mood-tour-card .tour-body {
    color: #e5e7eb;
    margin-bottom: 0.85rem;
  }
  #mood-tour-card .tour-controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  #mood-tour-card .tour-counter {
    color: #6b7280;
    font-size: 0.65rem;
    font-variant-numeric: tabular-nums;
    letter-spacing: 0.1em;
  }
  #mood-tour-card .tour-right {
    display: flex;
    gap: 0.4rem;
  }
  #mood-tour-card button {
    background: none;
    border: none;
    color: #9ca3af;
    cursor: pointer;
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    padding: 0.3rem 0.55rem;
    border-radius: 4px;
    transition: color 120ms ease, background 120ms ease;
  }
  #mood-tour-card button:hover {
    color: #f3f4f6;
    background: rgba(255, 255, 255, 0.05);
  }
  #mood-tour-card button[data-tour-primary] {
    color: #e5e7eb;
  }
  #mood-tour-card button[data-tour-primary]:hover {
    color: #ffffff;
    background: rgba(255, 255, 255, 0.08);
  }
`

function setSkipped(v) {
  try {
    if (v) localStorage.setItem(FLAG_KEY, "1")
    else localStorage.removeItem(FLAG_KEY)
  } catch (_e) {}
}

export const MoodTour = {
  mounted() {
    this.injectStyles()
    this.index = -1
    this.active = false
    this.currentTarget = null
    this.card = null

    this.clickHandler = (e) => {
      if (e.target.closest("[data-start-tour]")) {
        e.preventDefault()
        this.start()
      }
    }
    document.addEventListener("click", this.clickHandler)

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
    const style = document.getElementById("mood-tour-styles")
    if (style && style.parentNode) style.parentNode.removeChild(style)
  },

  injectStyles() {
    if (document.getElementById("mood-tour-styles")) return
    const el = document.createElement("style")
    el.id = "mood-tour-styles"
    el.textContent = STYLES
    document.head.appendChild(el)
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
    const target = document.getElementById(step.id)
    if (!target) {
      this.next()
      return
    }
    // <details> targets: open them so the spotlight highlights actual content
    if (target.tagName === "DETAILS" && !target.open) target.open = true

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    // Wait for the smooth scroll to settle before applying the shadow,
    // otherwise the dim layer shifts mid-animation.
    setTimeout(() => {
      target.classList.add("mood-tour-spotlight")
      this.currentTarget = target
    }, 260)

    this.card.querySelector("[data-tour-title]").textContent = step.title
    this.card.querySelector("[data-tour-body]").textContent = step.body
    this.card.querySelector("[data-tour-counter]").textContent =
      `${this.index + 1} / ${STEPS.length}`

    const primary = this.card.querySelector("[data-tour-primary]")
    primary.innerHTML = this.index === STEPS.length - 1 ? "Done" : "Next &rsaquo;"

    const prevBtn = this.card.querySelector('[data-tour-action="prev"]')
    prevBtn.style.visibility = this.index === 0 ? "hidden" : "visible"
  },

  finish() {
    this.clearSpotlight()
    this.teardownCard()
    this.active = false
    setSkipped(true)
    const intro = document.getElementById("mood-intro")
    if (intro) intro.style.display = "none"
    const link = document.getElementById("mood-show-intro")
    if (link) link.style.display = "inline-block"
    const ch1 = document.getElementById("mood-chapter-1")
    if (ch1) ch1.scrollIntoView({ behavior: "smooth", block: "start" })
  },

  cancel() {
    this.clearSpotlight()
    this.teardownCard()
    this.active = false
  },
}
