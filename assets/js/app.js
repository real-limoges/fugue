// Import existing stuff
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// ADD THIS - your new import
import { GraphViz } from "./hooks/graph_viz"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// ADD THIS - hooks object
let Hooks = {
  GraphViz: GraphViz
}

// MODIFY THIS - add hooks to the config
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,  // <-- ADD THIS LINE
  params: {_csrf_token: csrfToken}
})

// Keep everything below this (topbar setup, etc)
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket