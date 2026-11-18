// Types for the vendored petri langton wrapper (assets/vendor/petri/js/langton.js).
// See README.md in this directory.

export function init(): Promise<void>

/** Places `count` ants on a blank `width` x `height` grid. */
export function start(count: number, width: number, height: number): void

/** Advances every ant `n` steps. */
export function step(n: number): void

/** One intensity byte per cell, `width * height` long, a view into WASM memory. */
export function getPixels(): Uint8Array
