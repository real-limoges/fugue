// @ts-check
// DOM lookups for hooks that query back into markup they wrote themselves.

/**
 * The first match for `selector` under `root`, checked to be a `type`.
 * Throws rather than returning null: the caller wrote the markup, so a
 * missing or mistyped element is a bug in the caller, not a page state.
 *
 * @template {Element} T
 * @param {ParentNode} root
 * @param {string} selector
 * @param {{new (): T, prototype: T}} type e.g. HTMLInputElement, SVGSVGElement
 * @returns {T}
 */
export function requireElement(root, selector, type) {
  const el = root.querySelector(selector)
  if (!(el instanceof type)) throw new Error(`expected ${type.name} at ${selector}`)
  return el
}
