// Types for the vendored petri sandpile wrapper (assets/vendor/petri/js/sandpile.js).
// See README.md in this directory.

export function init(): Promise<void>

/** Clears the pile to an empty `width` x `height` grid. */
export function start(width: number, height: number): void

/** Drops `n` grains, toppling after each. */
export function step(n: number): void

export function drop(x: number, y: number): void
export function dropCenter(): void
export function dropRandom(): void

/** 0 drops at the center, 1 at random cells. */
export function setMode(mode: number): void

/** Cells toppled by the most recent drop. */
export function getLastAvalancheSize(): number

export function getTotalGrains(): number

/** One intensity byte per cell, `width * height` long, a view into WASM memory. */
export function getPixels(): Uint8Array
