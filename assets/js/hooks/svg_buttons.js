// @ts-check
// Gives SVG shapes marked role="button" the keyboard behavior of a real
// button: Enter or Space on a focused one fires its click, so the shape's
// existing phx-click runs and the server side stays the only handler.
// LiveView cannot do this alone: phx-keydown has no way to cancel the
// browser default, and Space on a focused shape would also scroll the page.
// One listener on the container covers every shape inside it, including
// ones LiveView patches in later.

/**
 * Whether a key activates a button, per the ARIA button pattern.
 *
 * @param {string} key a `KeyboardEvent.key` value
 */
export function isActivationKey(key) {
  return key === "Enter" || key === " "
}

/**
 * @typedef {object} State
 * @property {(e: KeyboardEvent) => void} _onKeydown
 */

/** @type {import("../types").LiveHook<State>} */
export const SvgButtons = {
  mounted() {
    /** @param {KeyboardEvent} e */
    this._onKeydown = (e) => {
      const target = e.target
      if (!(target instanceof Element) || target.getAttribute("role") !== "button") return
      if (!isActivationKey(e.key) || e.repeat) return

      e.preventDefault()
      target.dispatchEvent(new MouseEvent("click", { bubbles: true }))
    }
    this.el.addEventListener("keydown", this._onKeydown)
  },

  destroyed() {
    this.el.removeEventListener("keydown", this._onKeydown)
  },
}
