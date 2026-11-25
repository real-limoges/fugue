// @ts-check
import "phoenix_html"
import { initSplash } from "./petri_splash"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks/index"
import { requireElement } from "./lib/dom.js"

let csrfToken = requireElement(document, "meta[name='csrf-token']", HTMLMetaElement).getAttribute(
  "content"
)

// /mood remembers whether the reader skipped its intro. The server renders
// from this connect param; the "mood:intro" event that the Skip and Show
// buttons dispatch (FugueWeb.MoodLive.Sections) writes it back.
const MOOD_SKIP_INTRO = "mood-skip-intro"

/** @returns {string | null} */
function readMoodSkipIntro() {
  try {
    return localStorage.getItem(MOOD_SKIP_INTRO)
  } catch (_e) {
    return null
  }
}

window.addEventListener("mood:intro", (e) => {
  const skipped = e instanceof CustomEvent && e.detail?.skipped === true
  try {
    if (skipped) localStorage.setItem(MOOD_SKIP_INTRO, "1")
    else localStorage.removeItem(MOOD_SKIP_INTRO)
  } catch (_e) {}
  // JS.hide/JS.show apply `display` in a requestAnimationFrame, after this
  // event has fired. Scroll two frames later so it measures the page with
  // the intro already hidden or shown.
  const target = e.target
  if (target instanceof Element) {
    requestAnimationFrame(() =>
      requestAnimationFrame(() => target.scrollIntoView({ behavior: "smooth", block: "start" }))
    )
  }
})

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  // A function, so every join (including a rejoin after a dropped socket)
  // reads the flag again rather than the value from page load.
  params: () => ({ _csrf_token: csrfToken, mood_skip_intro: readMoodSkipIntro() }),
  hooks: Hooks,
})

// Keep everything below this (topbar setup, etc)
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300))
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket

if (document.getElementById("petri-canvas")) {
  const picker = document.getElementById("sim-picker")
  const select = picker instanceof HTMLSelectElement ? picker : null
  const defaultSim = select ? select.value : "boids"
  initSplash("petri-canvas", defaultSim, "sim-reading")

  if (select) {
    select.addEventListener("change", () => {
      initSplash("petri-canvas", select.value, "sim-reading")
    })
  }
}

// three.js is most of the bundle by weight and only /about uses it, so it is
// loaded on demand; esbuild's --splitting puts it in its own chunk.
if (document.getElementById("lego-stack")) {
  import("./lego_3d").then(({ initLego3D }) => initLego3D("lego-stack"))
}
