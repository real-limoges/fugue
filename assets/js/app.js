import "phoenix_html"
import { initSplash, simNames } from "./petri_splash"
import { initLego3D } from "./lego_3d"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks/index"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
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
  const defaultSim = picker ? picker.value : "physarum"
  initSplash("petri-canvas", defaultSim, "sim-reading")

  if (picker) {
    picker.addEventListener("change", (e) => {
      initSplash("petri-canvas", e.target.value, "sim-reading")
    })
  }
}

if (document.getElementById("lego-stack")) {
  initLego3D("lego-stack")
}
