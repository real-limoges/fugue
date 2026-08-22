// Flips the site's light/dark theme. Purely client-side: no LiveView
// round-trip needed. Persists the explicit choice to localStorage so it
// survives reloads and overrides the system preference from then on;
// until the user picks one, a matchMedia listener keeps following the OS
// setting. Dispatches "fugue:theme-changed" so themed canvas hooks
// (theme_colors.js consumers) can repaint immediately instead of waiting
// for their next poll.

const STORAGE_KEY = "fugue-theme"

function applyTheme(theme) {
  document.documentElement.setAttribute("data-theme", theme)
  window.dispatchEvent(new CustomEvent("fugue:theme-changed", { detail: { theme } }))
}

export const ThemeToggle = {
  mounted() {
    this._media = matchMedia("(prefers-color-scheme: dark)")
    this._onMediaChange = (e) => {
      if (localStorage.getItem(STORAGE_KEY) === null) {
        applyTheme(e.matches ? "dark" : "light")
      }
    }
    this._media.addEventListener("change", this._onMediaChange)

    this.el.addEventListener("click", () => {
      const next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark"
      localStorage.setItem(STORAGE_KEY, next)
      applyTheme(next)
    })
  },

  destroyed() {
    this._media.removeEventListener("change", this._onMediaChange)
  },
}
