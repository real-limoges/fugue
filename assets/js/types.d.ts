// Shared types for JSDoc-annotated hooks. Declarations only; esbuild never
// sees this file, since nothing imports it at runtime.

import type { Hook, HookInterface, LiveSocket } from "phoenix_live_view"

declare global {
  interface Window {
    // app.js exposes the socket for debugging from the console
    // (liveSocket.enableDebug() and friends).
    liveSocket: LiveSocket
  }
}

/**
 * A LiveView hook object.
 *
 * `State` is the fields the callbacks assign onto `this` (a tooltip element,
 * bound listeners). `Methods` is any helper functions written on the object
 * literal itself. Keeping them apart lets the literal be checked for exactly
 * the methods it declares, while `this` inside every callback sees both.
 *
 * `Hook` types `this` for the lifecycle callbacks only. `ThisType` extends
 * the same `this` to the helper methods; without it `this` inside a helper
 * is silently `any` and nothing in the helper is checked.
 *
 * Usage in a hook file:
 *
 *     /** @type {import("../types").LiveHook<{tip: HTMLDivElement}>} *\/
 *     export const MyHook = { mounted() { this.tip = ... } }
 */
export type LiveHook<State, Methods = {}> = Hook<State & Methods> &
  Methods &
  ThisType<State & Methods & HookInterface>
