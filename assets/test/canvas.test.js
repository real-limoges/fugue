import { describe, expect, test } from "vitest"
import { createThemePoll, mapPixels } from "../js/lib/canvas_loop.js"
import { buildColorTable } from "../js/lib/theme_colors.js"

describe("buildColorTable", () => {
  const base = [10, 20, 30]
  const primary = [210, 120, 30]
  const table = buildColorTable(base, primary)

  test("has 256 RGBA entries", () => {
    expect(table.length).toBe(256 * 4)
  })

  test("starts at the base color and ends at the primary, fully opaque", () => {
    expect(Array.from(table.slice(0, 4))).toEqual([10, 20, 30, 255])
    expect(Array.from(table.slice(255 * 4))).toEqual([210, 120, 30, 255])
  })

  test("eases in: the midpoint sits a quarter of the way, not half", () => {
    const mid = 128 * 4
    const t2 = (128 / 255) ** 2
    expect(table[mid]).toBe(10 + Math.round(200 * t2))
    expect(table[mid]).toBeLessThan(110)
  })
})

describe("mapPixels", () => {
  test("looks each intensity up in the color table", () => {
    const table = buildColorTable([0, 0, 0], [255, 255, 255])
    const intensity = new Uint8Array([0, 255])
    const rgba = new Uint8ClampedArray(8)

    mapPixels(intensity, table, rgba)

    expect(Array.from(rgba)).toEqual([0, 0, 0, 255, 255, 255, 255, 255])
  })
})

describe("createThemePoll", () => {
  test("fires once every N calls", () => {
    let fired = 0
    const poll = createThemePoll({ frames: 3, onChange: () => fired++ })

    for (let i = 0; i < 7; i++) poll()

    expect(fired).toBe(2)
  })
})
