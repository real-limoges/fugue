// Iridescent thin-film surface for /color section 1. Cuttlefish-papillae
// thickness map driven by a Voronoi field; cursor proximity maps to
// effective viewing angle so the rainbow shifts as you hover. WebGL2
// fragment shader; no WASM, no shader build step.

const VERT_SRC = `#version 300 es
in vec2 a_pos;
void main() {
  gl_Position = vec4(a_pos, 0.0, 1.0);
}
`

const FRAG_SRC = `#version 300 es
precision highp float;

uniform vec2 u_res;
uniform vec2 u_cursor;
uniform float u_time;

out vec4 fragColor;

float hash1(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash1(i);
  float b = hash1(i + vec2(1.0, 0.0));
  float c = hash1(i + vec2(0.0, 1.0));
  float d = hash1(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * vnoise(p);
    p = p * 2.0 + vec2(11.3, 5.7);
    a *= 0.5;
  }
  return v;
}

// Domain-warped fbm. Feeds an fbm result back into its own input twice
// to produce flowing organic swirls -- no cells, no spots, no holes.
float swirl(vec2 p, float t) {
  vec2 q = vec2(
    fbm(p + vec2(0.0, t * 0.06)),
    fbm(p + vec2(5.2, 1.3) + vec2(t * 0.05, 0.0))
  );
  vec2 r = vec2(
    fbm(p + 3.5 * q + vec2(1.7, 9.2)),
    fbm(p + 3.5 * q + vec2(8.3, 2.8))
  );
  return fbm(p + 3.5 * r);
}

// Flamboyant-cuttlefish palette: deep crimson -> bright red -> magenta
// -> burnt orange -> cream-yellow -> wine, then back. No greens, no
// blues, no cyans -- just the vivid warning-coloration band these
// animals wear when they're not bothering to hide.
vec3 flamboyantPalette(float t) {
  t = fract(t);
  if (t < 0.2)      return mix(vec3(0.45, 0.04, 0.10), vec3(0.95, 0.08, 0.18), t * 5.0);
  else if (t < 0.4) return mix(vec3(0.95, 0.08, 0.18), vec3(0.85, 0.10, 0.55), (t - 0.2) * 5.0);
  else if (t < 0.6) return mix(vec3(0.85, 0.10, 0.55), vec3(1.00, 0.42, 0.12), (t - 0.4) * 5.0);
  else if (t < 0.8) return mix(vec3(1.00, 0.42, 0.12), vec3(1.00, 0.86, 0.55), (t - 0.6) * 5.0);
  else              return mix(vec3(1.00, 0.86, 0.55), vec3(0.45, 0.04, 0.10), (t - 0.8) * 5.0);
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_res;
  vec2 aspect = vec2(u_res.x / u_res.y, 1.0);

  // Flowing thickness field -- domain-warped fbm, organic swirls.
  float thicknessField = swirl(uv * aspect * 2.4, u_time);

  // Optical path length, no cursor influence on geometry.
  float n_film = 1.33;
  float thickness = 0.30 + 0.70 * thicknessField;
  float opl = 2.0 * n_film * thickness;

  // Cursor as a faint global phase shift: moving the pointer slides the
  // whole palette one step, like a pet-the-cuttlefish nudge. No spatial
  // halo. No tilt. Nothing tracks the mouse.
  float cursorPhase = (u_cursor.x + u_cursor.y) * 0.15;
  float t = opl * 1.6 + cursorPhase;

  vec3 col = flamboyantPalette(t);

  // Cream highlights: drifting fbm gates bright pearl-yellow patches,
  // the white-yellow flecks a flamboyant cuttlefish wears alongside its
  // reds. Offset and counter-drift so they aren't synced with the dark
  // patches.
  float lightPatch = fbm(uv * aspect * 1.4 + vec2(100.0, 50.0) + vec2(u_time * 0.05, u_time * 0.08));
  float highlight = smoothstep(0.62, 0.78, lightPatch);
  vec3 highlightColor = vec3(1.00, 0.92, 0.65);
  col = mix(col, highlightColor, highlight * 0.55);

  // Chromatophore patches: drifting fbm gates regions of dark wine
  // pigment. Sharper smoothstep edges so the pigment cells look
  // committed, not foggy.
  float darkPatch = fbm(uv * aspect * 1.6 + vec2(u_time * 0.07, u_time * 0.04));
  float pigment = smoothstep(0.60, 0.72, darkPatch);

  // Passing-cloud display: a traveling wave of darkness sweeps across
  // the surface periodically, modulated by fbm so the front isn't a
  // straight line. The wave momentarily intensifies the chromatophore
  // patches as it passes -- the signature cuttlefish move.
  float cloudPhase = uv.x * 1.5 - u_time * 0.3;
  float cloudWave = pow(0.5 + 0.5 * sin(cloudPhase + fbm(uv * aspect * 1.0) * 2.5), 4.0);
  pigment *= 0.4 + 1.2 * cloudWave;
  pigment = clamp(pigment, 0.0, 1.0);

  vec3 pigmentColor = vec3(0.10, 0.02, 0.04);
  col = mix(col, pigmentColor, pigment * 0.85);

  // Soft vignette so the panel feels seated, not edge-to-edge clipped.
  float vig = 1.0 - 0.18 * smoothstep(0.5, 1.05, length((uv - 0.5) * 2.0));
  col *= vig;

  fragColor = vec4(col, 1.0);
}
`

function compileShader(gl, type, src) {
  const sh = gl.createShader(type)
  gl.shaderSource(sh, src)
  gl.compileShader(sh)
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    console.error("[IridescenceCanvas] shader compile error:", gl.getShaderInfoLog(sh))
    console.error(src)
    return null
  }
  return sh
}

function applyFallback(canvas) {
  // Spectrum-strip CSS gradient so non-WebGL2 clients still see color.
  // This is chrome, not the flamboyant-cuttlefish content above -- it
  // reads the live theme accents rather than carrying its own palette.
  const style = getComputedStyle(document.documentElement)
  const stops = [
    style.getPropertyValue("--color-secondary").trim(),
    style.getPropertyValue("--color-info").trim(),
    style.getPropertyValue("--color-accent").trim(),
    style.getPropertyValue("--color-warning").trim(),
    style.getPropertyValue("--color-primary").trim(),
    style.getPropertyValue("--color-error").trim(),
  ]
  canvas.style.background = `linear-gradient(90deg,${stops[0]} 0%,${stops[1]} 25%,${stops[2]} 50%,${stops[3]} 70%,${stops[4]} 85%,${stops[5]} 100%)`
}

export const IridescenceCanvas = {
  async mounted() {
    try {
      await new Promise((r) => requestAnimationFrame(r))
      const canvas = this.el
      const rect = canvas.getBoundingClientRect()
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      const W = Math.max(1, Math.floor(rect.width * dpr))
      const H = Math.max(1, Math.floor(rect.height * dpr))
      canvas.width = W
      canvas.height = H

      const gl = canvas.getContext("webgl2", {
        antialias: true,
        premultipliedAlpha: false,
      })
      if (!gl) {
        applyFallback(canvas)
        return
      }

      const vs = compileShader(gl, gl.VERTEX_SHADER, VERT_SRC)
      const fs = compileShader(gl, gl.FRAGMENT_SHADER, FRAG_SRC)
      if (!vs || !fs) {
        applyFallback(canvas)
        return
      }
      const prog = gl.createProgram()
      gl.attachShader(prog, vs)
      gl.attachShader(prog, fs)
      gl.linkProgram(prog)
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
        console.error("[IridescenceCanvas] link failed:", gl.getProgramInfoLog(prog))
        applyFallback(canvas)
        return
      }
      gl.useProgram(prog)

      const buf = gl.createBuffer()
      gl.bindBuffer(gl.ARRAY_BUFFER, buf)
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)
      const aPos = gl.getAttribLocation(prog, "a_pos")
      gl.enableVertexAttribArray(aPos)
      gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0)

      const uRes = gl.getUniformLocation(prog, "u_res")
      const uCursor = gl.getUniformLocation(prog, "u_cursor")
      const uTime = gl.getUniformLocation(prog, "u_time")

      gl.viewport(0, 0, W, H)
      gl.uniform2f(uRes, W, H)

      // Cursor state. y is flipped to GL convention (y-up).
      let cx = 0.5
      let cy = 0.5

      const updateCursor = (clientX, clientY) => {
        const r = canvas.getBoundingClientRect()
        cx = (clientX - r.left) / r.width
        cy = 1 - (clientY - r.top) / r.height
      }
      const onMouseMove = (e) => updateCursor(e.clientX, e.clientY)
      const onTouchMove = (e) => {
        if (e.touches.length > 0) {
          updateCursor(e.touches[0].clientX, e.touches[0].clientY)
        }
      }
      canvas.addEventListener("mousemove", onMouseMove)
      canvas.addEventListener("touchmove", onTouchMove, { passive: true })

      const start = performance.now()
      let rafId = null
      const loop = () => {
        const t = (performance.now() - start) / 1000
        gl.uniform1f(uTime, t)
        gl.uniform2f(uCursor, cx, cy)
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
        rafId = requestAnimationFrame(loop)
      }
      rafId = requestAnimationFrame(loop)

      this._stopLoop = () => {
        if (rafId !== null) cancelAnimationFrame(rafId)
        canvas.removeEventListener("mousemove", onMouseMove)
        canvas.removeEventListener("touchmove", onTouchMove)
        gl.deleteProgram(prog)
        gl.deleteBuffer(buf)
      }
    } catch (err) {
      console.error("[IridescenceCanvas] mount failed:", err)
    }
  },

  destroyed() {
    if (this._stopLoop) this._stopLoop()
  },
}
