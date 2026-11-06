// @ts-check
// Manages the "skip intro / show intro" state for the mood page.
// One flag in localStorage: mood-skip-intro = '1' means the preamble and
// sandbox are hidden and a small "show intro" link appears near Chapter 1.

const FLAG_KEY = "mood-skip-intro"

function isSkipped() {
  try {
    return localStorage.getItem(FLAG_KEY) === "1"
  } catch (_e) {
    return false
  }
}

/** @param {boolean} skipped */
function setSkipped(skipped) {
  try {
    if (skipped) localStorage.setItem(FLAG_KEY, "1")
    else localStorage.removeItem(FLAG_KEY)
  } catch (_e) {}
}

/**
 * @typedef {object} State
 * @property {(e: MouseEvent) => void} clickHandler
 */

/**
 * @typedef {object} Methods
 * @property {(skipped: boolean) => void} applyState
 */

/** @type {import("../types").LiveHook<State, Methods>} */
export const MoodIntroGate = {
  mounted() {
    this.applyState(isSkipped())

    /** @param {MouseEvent} e */
    this.clickHandler = (e) => {
      if (!(e.target instanceof Element)) return
      if (e.target.closest("[data-skip-intro]")) {
        e.preventDefault()
        setSkipped(true)
        this.applyState(true)
        const ch1 = document.getElementById("mood-chapter-1")
        if (ch1) ch1.scrollIntoView({ behavior: "smooth", block: "start" })
        return
      }
      if (e.target.closest("[data-show-intro]")) {
        e.preventDefault()
        setSkipped(false)
        this.applyState(false)
        this.el.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    }
    document.addEventListener("click", this.clickHandler)
  },

  destroyed() {
    if (this.clickHandler) {
      document.removeEventListener("click", this.clickHandler)
    }
  },

  applyState(skipped) {
    this.el.style.display = skipped ? "none" : ""
    const link = document.getElementById("mood-show-intro")
    if (link) link.style.display = skipped ? "inline-block" : "none"
  },
}
