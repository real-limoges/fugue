import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { createFrameGate, startRafLoop } from "../js/lib/canvas_loop.js"

// startRafLoop talks to four browser APIs. The test replaces each with a
// small fake it can drive by hand: frames run only when `runFrame` is
// called, visibility and intersection change only when the test says so.
let frames
let nextId
let observerCallback
let observerDisconnected
let docListeners
let reducedMotion

const fakeDocument = {
  visibilityState: "visible",
  addEventListener: (type, fn) => docListeners.set(type, fn),
  removeEventListener: (type) => docListeners.delete(type),
}

function runFrame(now = 16) {
  const pending = [...frames.values()]
  frames.clear()
  pending.forEach((fn) => fn(now))
}

function setOnScreen(isIntersecting) {
  observerCallback([{ isIntersecting }])
}

function setTabVisible(visible) {
  fakeDocument.visibilityState = visible ? "visible" : "hidden"
  docListeners.get("visibilitychange")()
}

beforeEach(() => {
  frames = new Map()
  nextId = 1
  observerDisconnected = false
  docListeners = new Map()
  reducedMotion = false
  fakeDocument.visibilityState = "visible"

  vi.stubGlobal("document", fakeDocument)
  vi.stubGlobal("requestAnimationFrame", (fn) => {
    const id = nextId++
    frames.set(id, fn)
    return id
  })
  vi.stubGlobal("cancelAnimationFrame", (id) => frames.delete(id))
  vi.stubGlobal("matchMedia", () => ({ matches: reducedMotion }))
  vi.stubGlobal(
    "IntersectionObserver",
    class {
      constructor(callback) {
        observerCallback = callback
      }
      observe() {}
      disconnect() {
        observerDisconnected = true
      }
    }
  )
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("startRafLoop", () => {
  test("steps once per frame, with the frame's timestamp", () => {
    const step = vi.fn()
    startRafLoop(step, { target: {} })

    runFrame(100)
    runFrame(116)

    expect(step).toHaveBeenCalledTimes(2)
    expect(step).toHaveBeenLastCalledWith(116)
  })

  test("pauses while the target is offscreen and resumes when it comes back", () => {
    const step = vi.fn()
    startRafLoop(step, { target: {} })

    setOnScreen(false)
    runFrame()
    runFrame()
    expect(step).not.toHaveBeenCalled()

    setOnScreen(true)
    runFrame()
    expect(step).toHaveBeenCalledTimes(1)
  })

  test("pauses while the tab is hidden", () => {
    const step = vi.fn()
    startRafLoop(step, { target: {} })

    setTabVisible(false)
    runFrame()
    expect(step).not.toHaveBeenCalled()

    setTabVisible(true)
    runFrame()
    expect(step).toHaveBeenCalledTimes(1)
  })

  test("never schedules two frames at once when signals repeat", () => {
    startRafLoop(() => {}, { target: {} })

    setOnScreen(true)
    setTabVisible(true)
    setOnScreen(true)

    expect(frames.size).toBe(1)
  })

  test("stop cancels the frame and removes its listeners", () => {
    const step = vi.fn()
    const loop = startRafLoop(step, { target: {} })

    loop.stop()
    runFrame()

    expect(step).not.toHaveBeenCalled()
    expect(observerDisconnected).toBe(true)
    expect(docListeners.has("visibilitychange")).toBe(false)
  })

  test("under reduced motion, draws the still once and starts no loop", () => {
    reducedMotion = true
    const step = vi.fn()
    const still = vi.fn()

    startRafLoop(step, { target: {}, still })
    runFrame()

    expect(still).toHaveBeenCalledTimes(1)
    expect(step).not.toHaveBeenCalled()
    expect(frames.size).toBe(0)
  })

  test("under reduced motion, a loop with no still keeps running", () => {
    reducedMotion = true
    const step = vi.fn()

    startRafLoop(step, { target: {} })
    runFrame()

    expect(step).toHaveBeenCalledTimes(1)
  })

  test("with fps, frames that come early skip the step", () => {
    const step = vi.fn()

    startRafLoop(step, { target: {}, fps: 60 })
    ;[0, 8.3, 16.7, 25, 33.3].forEach((t) => runFrame(t))

    expect(step.mock.calls.map(([now]) => now)).toEqual([0, 16.7, 33.3])
  })
})

// How many of `seconds` worth of frames at `hz` a gate capped at `fps` lets through.
function passedPerSecond(fps, hz, seconds = 10) {
  const due = createFrameGate(fps)
  let passed = 0
  for (let i = 0; i < hz * seconds; i++) if (due((i * 1000) / hz)) passed++
  return passed / seconds
}

describe("createFrameGate", () => {
  test("on a 60 Hz screen a 60 cap runs every frame", () => {
    expect(passedPerSecond(60, 60)).toBe(60)
  })

  test("on a 120 Hz screen a 60 cap runs every other frame", () => {
    expect(passedPerSecond(60, 120)).toBe(60)
  })

  test("on a 144 Hz screen a 60 cap still averages 60", () => {
    expect(passedPerSecond(60, 144)).toBeCloseTo(60, 0)
  })

  test("a frame that lands a little early still counts as on time", () => {
    const due = createFrameGate(60)
    due(0)
    expect(due(15.5)).toBe(true)
  })

  test("after a pause it runs at once and does not catch up", () => {
    const due = createFrameGate(60)
    due(0)
    expect(due(5000)).toBe(true)
    expect(due(5008)).toBe(false)
    expect(due(5016.7)).toBe(true)
  })
})
