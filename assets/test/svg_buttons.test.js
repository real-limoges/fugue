import { describe, expect, test } from "vitest"
import { isActivationKey } from "../js/hooks/svg_buttons.js"

describe("isActivationKey", () => {
  test("Enter and Space activate, as on a native button", () => {
    expect(isActivationKey("Enter")).toBe(true)
    expect(isActivationKey(" ")).toBe(true)
  })

  test("navigation and other keys do not", () => {
    for (const key of ["Tab", "Escape", "ArrowDown", "Spacebar", "enter", "a"]) {
      expect(isActivationKey(key)).toBe(false)
    }
  })
})
