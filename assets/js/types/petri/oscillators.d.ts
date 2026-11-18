// Types for the vendored petri oscillators wrapper (assets/vendor/petri/js/oscillators.js).
// See README.md in this directory.

export function init(): Promise<void>

/** Seeds a `width` x `height` field of oscillators at random phases. */
export function start(width: number, height: number): void

/** Advances the field `n` steps. */
export function step(n: number): void

export function setCoupling(k: number): void

/** One intensity byte per cell, `width * height` long, a view into WASM memory. */
export function getPixels(): Uint8Array
