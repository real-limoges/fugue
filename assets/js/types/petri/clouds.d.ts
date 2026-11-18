// Types for the vendored petri clouds wrapper (assets/vendor/petri/js/clouds.js).
// See README.md in this directory.

/** Fetches the WASM, initializes the solver and reads its grid size. */
export function init(): Promise<void>

export function step(n: number): void
export function setWind(u: number): void
export function setWeather(w: number): void
export function seed(p: number): void

/** A Gaussian warm anomaly at (x_m, z_m), peak `dT_K` kelvin, 1-sigma `radius_m` meters. */
export function applyBubble(x_m: number, z_m: number, dT_K: number, radius_m: number): void

/** Cloud water mixing ratio, `NX * NZ` long, indexed `iz * NX + ix`; a stable view into WASM memory. */
export function getQC(): Float32Array

export const grid: {
  readonly NX: number
  readonly NZ: number
  readonly DX: number
  readonly DZ: number
  readonly widthM: number
  readonly heightM: number
}
