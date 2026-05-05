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

vec2 hash2(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

// Voronoi-cell papillae. Returns dome height at uv, animated by t so
// cell centers drift even when the cursor is still.
float papillae(vec2 uv, float t) {
  vec2 ip = floor(uv);
  vec2 fp = fract(uv);
  float minD = 8.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 g = vec2(float(i), float(j));
      vec2 o = 0.5 + 0.5 * sin(t * 0.35 + 6.2831853 * hash2(ip + g));
      vec2 r = g + o - fp;
      float d = dot(r, r);
      minD = min(minD, d);
    }
  }
  return 1.0 - smoothstep(0.0, 0.65, sqrt(minD));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_res;
  vec2 aspect = vec2(u_res.x / u_res.y, 1.0);

  // ~5 cells across; aspect-corrected so cells stay round on wide canvases
  float h = papillae(uv * aspect * 5.5, u_time);

  // Effective viewing angle from cursor: head-on near cursor, grazing far
  vec2 toC = (uv - u_cursor) * aspect;
  float cosTheta = clamp(1.0 - length(toC) * 0.7, 0.25, 1.0);

  // Optical path length difference. n_film ~= water; thickness biased so
  // even dome valleys still produce some color.
  float n_film = 1.33;
  float thickness = 0.35 + 0.65 * h;
  float opl = 2.0 * n_film * thickness * cosTheta;

  // Newton's-series iridescent palette: three offset cosines on the OPL
  // produce silver/gold/magenta/blue/cyan/yellow as opl sweeps.
  float phase = opl * 4.5 * 6.2831853;
  vec3 col = 0.5 + 0.5 * vec3(
    cos(phase),
    cos(phase + 2.0944),
    cos(phase + 4.1888)
  );

  // Grazing-angle dimming so the surface has depth, not a flat sticker
  col *= 0.55 + 0.45 * cosTheta;

  // Soft vignette so the panel feels seated, not edge-to-edge clipped
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
  // Spectrum-strip CSS gradient so non-WebGL2 clients still see color
  canvas.style.background =
    "linear-gradient(90deg,#5a4cff 0%,#22d3ee 25%,#84cc16 50%,#facc15 70%,#f97316 85%,#ef4444 100%)"
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
      gl.bufferData(
        gl.ARRAY_BUFFER,
        new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
        gl.STATIC_DRAW
      )
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
