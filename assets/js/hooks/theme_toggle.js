// @ts-check
// Flips the site's light/dark theme. Purely client-side: no LiveView
// round-trip needed. Persists the explicit choice to localStorage so it
// survives reloads and overrides the system preference from then on;
// until the user picks one, a matchMedia listener keeps following the OS
// setting. Dispatches "fugue:theme-changed" so themed canvas hooks
// (theme_colors.js consumers) repaint; it is their only signal, so every
// theme change must go through applyTheme. Also points the theme-color meta (the mobile
// browser bar) at the new theme's color, which the root layout keeps in
// that meta's data attributes.

const STORAGE_KEY = "fugue-theme"

/** @param {"light" | "dark"} theme */
function applyTheme(theme) {
  document.documentElement.setAttribute("data-theme", theme)
  const bar = document.querySelector('meta[name="theme-color"]')
  if (bar instanceof HTMLMetaElement) bar.content = bar.dataset[theme] ?? bar.content
  window.dispatchEvent(new CustomEvent("fugue:theme-changed", { detail: { theme } }))
}

/**
 * @typedef {object} State
 * @property {MediaQueryList} _media
 * @property {(e: MediaQueryListEvent) => void} _onMediaChange
 */

/** @type {import("../types").LiveHook<State>} */
export const ThemeToggle = {
  mounted() {
    this._media = matchMedia("(prefers-color-scheme: dark)")
    /** @param {MediaQueryListEvent} e */
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
