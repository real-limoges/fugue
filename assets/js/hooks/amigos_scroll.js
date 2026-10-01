// Scroll driver for /amigos. Reports the highest beat marker the reader has
// scrolled past the middle of the viewport, going down or back up; the
// server owns what each beat shows. Readers who prefer reduced motion are
// switched to the finished, static page instead.

const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

export const AmigosScroll = {
  mounted() {
    this.lastBeat = Number(this.el.dataset.beat)
    this.frame = null

    if (window.matchMedia(REDUCED_MOTION).matches) {
      this.pushEvent("reduced_motion", {})
    }

    this.onScroll = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.report()
      })
    }

    // "watch it build" jumps to the top before the server swaps the page back
    // to the scroll track, so the first report afterwards starts from beat 1.
    this.onTop = () => window.scrollTo({ top: 0 })

    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.el.addEventListener("amigos:top", this.onTop)
    this.report()
  },

  updated() {
    this.lastBeat = Number(this.el.dataset.beat)
    this.report()
  },

  // A reconnect (deploy, sleep, flaky network) may have happened mid-scroll;
  // catch the server up on where the reader got to.
  reconnected() {
    this.report()
  },

  report() {
    if (this.el.dataset.mode !== "scroll") return
    if (!this.liveSocket.isConnected()) return

    const middle = window.innerHeight / 2
    const markers = this.el.querySelectorAll("[data-beat-marker]")
    const reached = Array.from(markers)
      .filter((marker) => marker.getBoundingClientRect().top <= middle)
      .map((marker) => Number(marker.dataset.beatMarker))
    const beat = Math.max(1, ...reached)

    if (beat !== this.lastBeat) {
      this.lastBeat = beat
      this.pushEvent("beat", { beat })
    }
  },

  destroyed() {
    window.removeEventListener("scroll", this.onScroll)
    this.el.removeEventListener("amigos:top", this.onTop)
    if (this.frame) cancelAnimationFrame(this.frame)
  },
}
