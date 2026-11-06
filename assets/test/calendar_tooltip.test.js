import { describe, expect, test } from "vitest"
import { cardHtml } from "../js/hooks/calendar_tooltip.js"

const clusters = { c0: { name: "Rested & calm", color: "#6ee64d" } }

describe("cardHtml", () => {
  test("lists dimensions in order and memberships with percent and bar width", () => {
    const html = cardHtml(
      { date: "2026-01-01", isGap: false, dims: "anxiety=2.0;sleep=7.5", mems: "c0=0.62;c9=0.38" },
      clusters
    )

    expect(html).toContain('<strong style="font-size: 13px">2026-01-01</strong>')
    expect(html.indexOf("anxiety")).toBeLessThan(html.indexOf("sleep"))
    expect(html).toContain("<strong>7.5</strong>")
    expect(html).toContain("62%")
    expect(html).toContain("width: 31px")
    // Unknown cluster ids fall back to the id and a gray, as the server did.
    expect(html).toContain(">c9</span>")
    expect(html).toContain("background: #888")
  })

  test("escapes cluster names", () => {
    const html = cardHtml({ date: "2026-01-01", isGap: false, dims: null, mems: "c0=1" }, clusters)
    expect(html).toContain("Rested &#38; calm")
    expect(html).not.toContain("Rested & calm")
  })

  test("a gap day with no data shows only the date and the gap tag", () => {
    const html = cardHtml({ date: "2026-01-10", isGap: true, dims: null, mems: null }, {})
    expect(html).toContain("gap day")
    expect(html).not.toContain("grid-template-columns")
    expect(html).not.toContain("border-top")
  })
})
