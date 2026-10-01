import { describe, expect, test } from "vitest"
import { bandPath, linspace, polylinePath } from "../js/lib/lab_chart.js"

const identity = (v) => v

describe("linspace", () => {
  test("includes both ends and spaces points evenly", () => {
    expect(linspace(0, 1, 5)).toEqual([0, 0.25, 0.5, 0.75, 1])
  })

  test("runs backwards when b < a", () => {
    expect(linspace(2, 0, 3)).toEqual([2, 1, 0])
  })
})

describe("polylinePath", () => {
  test("moves to the first point and draws lines to the rest", () => {
    expect(polylinePath([0, 1, 2], [5, 6, 7], identity, identity)).toBe("M0,5 L1,6 L2,7")
  })

  test("applies the scales to each coordinate", () => {
    const double = (v) => v * 2
    expect(polylinePath([1, 2], [3, 4], double, identity)).toBe("M2,3 L4,4")
  })
})

describe("bandPath", () => {
  test("traces the upper edge forward, the lower edge back, then closes", () => {
    expect(bandPath([0, 1, 2], [0, 0, 0], [9, 8, 7], identity, identity)).toBe(
      "M0,9 L1,8 L2,7 L2,0 L1,0 L0,0 Z"
    )
  })
})
