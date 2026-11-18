// Types for the vendored petri boids wrapper (assets/vendor/petri/js/boids.js).
// Written here because the vendor tree is an upstream drop; keep in step with
// the wrapper when petri is re-vendored. See README.md in this directory.

/** Fetches and instantiates the WASM module. Call once before anything else. */
export function init(): Promise<void>

/** Seeds `count` boids on a `width` x `height` field, replacing any running flock. */
export function start(count: number, width: number, height: number): void

/** Advances the flock `n` steps. */
export function step(n: number): void

/** One intensity byte per pixel, `width * height` long, a view into WASM memory. */
export function getPixels(): Uint8Array

export const DEFAULTS: Readonly<{
  count: number
  sep_radius: number
  align_radius: number
  cohesion_radius: number
  sep_force: number
  align_force: number
  cohesion_force: number
  max_speed: number
  min_speed: number
  trail_decay: number
  crowd_threshold: number
}>

export type Param = keyof typeof DEFAULTS

/** Sets one parameter; `count` is truncated to an integer. Unknown names are ignored. */
export function setParam(name: Param, value: number): void

export function setParams(params: Partial<Record<Param, number>>): void
