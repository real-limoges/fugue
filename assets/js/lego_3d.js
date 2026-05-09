import * as THREE from "three"

const STUD_UNIT = 1
const BRICK_HEIGHT = 1.2
const STUD_DIAMETER = 0.5
const STUD_HEIGHT = 0.22
const SPAWN_INTERVAL_MS = 550
const DRIFT_DURATION_MS = 1300
const HOLD_AFTER_BUILD_MS = 1800
const DISMANTLE_INTERVAL_MS = 220
const LEAVE_DURATION_MS = 900

const COLOR_PROPS = ["--color-primary", "--color-secondary", "--color-accent", "--color-info"]
const FALLBACKS = {
  "--color-primary": [200, 50, 180],
  "--color-secondary": [50, 180, 200],
  "--color-accent": [80, 200, 100],
  "--color-info": [80, 140, 220],
}

// Each shape is an ordered list of bricks. Build order is bottom-up so the
// structure looks like it's actually being assembled. {x, y, z, wx, wz} are
// integer stud-grid coordinates; wx is footprint along X, wz along Z.
const SHAPES = [
  // Stepped pyramid (4x4 base, 2x2 mid, 2x2 cap) -- 6 bricks
  [
    { x: 0, y: 0, z: 0, wx: 4, wz: 1 },
    { x: 0, y: 0, z: 1, wx: 4, wz: 1 },
    { x: 0, y: 0, z: 2, wx: 4, wz: 1 },
    { x: 0, y: 0, z: 3, wx: 4, wz: 1 },
    { x: 1, y: 1, z: 1, wx: 2, wz: 2 },
    { x: 1, y: 2, z: 1, wx: 2, wz: 2 },
  ],
  // Tower (2x2 cross-section, 5 levels, alternating brick orientation) -- 10 bricks
  [
    { x: 1, y: 0, z: 1, wx: 2, wz: 1 },
    { x: 1, y: 0, z: 2, wx: 2, wz: 1 },
    { x: 1, y: 1, z: 1, wx: 1, wz: 2 },
    { x: 2, y: 1, z: 1, wx: 1, wz: 2 },
    { x: 1, y: 2, z: 1, wx: 2, wz: 1 },
    { x: 1, y: 2, z: 2, wx: 2, wz: 1 },
    { x: 1, y: 3, z: 1, wx: 1, wz: 2 },
    { x: 2, y: 3, z: 1, wx: 1, wz: 2 },
    { x: 1, y: 4, z: 1, wx: 2, wz: 1 },
    { x: 1, y: 4, z: 2, wx: 2, wz: 1 },
  ],
  // Plus sign / cross (3 levels) -- 9 bricks
  [
    { x: 0, y: 0, z: 1, wx: 4, wz: 1 },
    { x: 0, y: 0, z: 2, wx: 4, wz: 1 },
    { x: 1, y: 0, z: 0, wx: 1, wz: 4 },
    { x: 2, y: 0, z: 0, wx: 1, wz: 4 },
    { x: 1, y: 1, z: 1, wx: 2, wz: 2 },
    { x: 1, y: 2, z: 1, wx: 1, wz: 2 },
    { x: 2, y: 2, z: 1, wx: 1, wz: 2 },
    { x: 1, y: 3, z: 1, wx: 2, wz: 1 },
    { x: 1, y: 3, z: 2, wx: 2, wz: 1 },
  ],
  // Arch / gate -- 8 bricks
  [
    { x: 0, y: 0, z: 1, wx: 1, wz: 2 },
    { x: 3, y: 0, z: 1, wx: 1, wz: 2 },
    { x: 0, y: 1, z: 1, wx: 1, wz: 2 },
    { x: 3, y: 1, z: 1, wx: 1, wz: 2 },
    { x: 0, y: 2, z: 1, wx: 1, wz: 2 },
    { x: 3, y: 2, z: 1, wx: 1, wz: 2 },
    { x: 0, y: 3, z: 1, wx: 4, wz: 1 },
    { x: 0, y: 3, z: 2, wx: 4, wz: 1 },
  ],
]

const GRID_W = 4
const GRID_D = 4

function readColor(prop) {
  const value = getComputedStyle(document.documentElement).getPropertyValue(prop).trim()
  const probe = document.createElement("canvas")
  probe.width = 1
  probe.height = 1
  const pctx = probe.getContext("2d", { willReadFrequently: true })
  pctx.fillStyle = "rgb(0,0,0)"
  pctx.fillRect(0, 0, 1, 1)
  pctx.fillStyle = value || `rgb(${FALLBACKS[prop].join(",")})`
  pctx.fillRect(0, 0, 1, 1)
  const [r, g, b] = pctx.getImageData(0, 0, 1, 1).data
  return new THREE.Color(r / 255, g / 255, b / 255)
}

function easeInOutCubic(t) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
}

function makeBrickMesh(wx, wz, color) {
  const group = new THREE.Group()
  const bodyGeom = new THREE.BoxGeometry(wx * STUD_UNIT, BRICK_HEIGHT, wz * STUD_UNIT)
  const bodyMat = new THREE.MeshStandardMaterial({
    color,
    roughness: 0.45,
    metalness: 0.05,
  })
  const body = new THREE.Mesh(bodyGeom, bodyMat)
  group.add(body)

  const studGeom = new THREE.CylinderGeometry(STUD_DIAMETER / 2, STUD_DIAMETER / 2, STUD_HEIGHT, 18)
  const studMat = new THREE.MeshStandardMaterial({
    color,
    roughness: 0.4,
    metalness: 0.05,
  })
  for (let i = 0; i < wx; i++) {
    for (let j = 0; j < wz; j++) {
      const stud = new THREE.Mesh(studGeom, studMat)
      stud.position.x = -((wx - 1) * STUD_UNIT) / 2 + i * STUD_UNIT
      stud.position.z = -((wz - 1) * STUD_UNIT) / 2 + j * STUD_UNIT
      stud.position.y = BRICK_HEIGHT / 2 + STUD_HEIGHT / 2
      group.add(stud)
    }
  }

  return group
}

function brickWorldCenter(brick, yOffset) {
  return new THREE.Vector3(
    (brick.x + (brick.wx - 1) / 2 - GRID_W / 2 + 0.5) * STUD_UNIT,
    brick.y * BRICK_HEIGHT + yOffset,
    (brick.z + (brick.wz - 1) / 2 - GRID_D / 2 + 0.5) * STUD_UNIT
  )
}

function shapeYOffset(shape) {
  let maxY = 0
  for (const brick of shape) {
    if (brick.y > maxY) maxY = brick.y
  }
  return -(maxY * BRICK_HEIGHT) / 2
}

export function initLego3D(canvasId) {
  const canvas = document.getElementById(canvasId)
  if (!canvas) return null

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true })
  renderer.setPixelRatio(window.devicePixelRatio || 1)

  const scene = new THREE.Scene()
  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100)
  const cameraDistance = 9.5
  const cameraHeight = 2.5

  const ambient = new THREE.AmbientLight(0xffffff, 0.55)
  scene.add(ambient)
  const key = new THREE.DirectionalLight(0xffffff, 0.9)
  key.position.set(4, 8, 5)
  scene.add(key)
  const fill = new THREE.DirectionalLight(0xffffff, 0.35)
  fill.position.set(-5, 3, -3)
  scene.add(fill)

  const colors = COLOR_PROPS.map(readColor)

  let bricks = []
  let spawning = null
  let lastSpawn = performance.now()
  let phase = "building"
  let phaseStart = performance.now()
  let dismantleQueue = []
  let lastDismantle = 0

  let currentShape = null
  let currentYOffset = 0
  let shapeIndex = 0
  let lastShapeIdx = -1

  function pickShape() {
    let idx
    do {
      idx = Math.floor(Math.random() * SHAPES.length)
    } while (SHAPES.length > 1 && idx === lastShapeIdx)
    lastShapeIdx = idx
    currentShape = SHAPES[idx]
    currentYOffset = shapeYOffset(currentShape)
    shapeIndex = 0
  }

  function spawnNextShapeBrick(now) {
    if (!currentShape || shapeIndex >= currentShape.length) return false
    const brickSpec = currentShape[shapeIndex++]
    const color = colors[Math.floor(Math.random() * colors.length)]
    const mesh = makeBrickMesh(brickSpec.wx, brickSpec.wz, color)
    const targetPos = brickWorldCenter(brickSpec, currentYOffset)

    const angle = Math.random() * Math.PI * 2
    const radius = 11 + Math.random() * 3
    const startPos = new THREE.Vector3(
      Math.cos(angle) * radius,
      targetPos.y + 5 + Math.random() * 3,
      Math.sin(angle) * radius
    )
    mesh.position.copy(startPos)
    mesh.rotation.set(
      (Math.random() - 0.5) * 0.6,
      (Math.random() - 0.5) * Math.PI,
      (Math.random() - 0.5) * 0.6
    )
    scene.add(mesh)

    spawning = {
      mesh,
      brickSpec,
      startPos,
      targetPos,
      startRot: { x: mesh.rotation.x, y: mesh.rotation.y, z: mesh.rotation.z },
      t0: now,
    }
    lastSpawn = now
    return true
  }

  function step(now) {
    if (phase === "building") {
      if (!currentShape) pickShape()
      if (!spawning && now - lastSpawn >= SPAWN_INTERVAL_MS) {
        const ok = spawnNextShapeBrick(now)
        if (!ok) {
          phase = "holding"
          phaseStart = now
        }
      }
      if (spawning) {
        const t = Math.min(1, (now - spawning.t0) / DRIFT_DURATION_MS)
        const e = easeInOutCubic(t)
        spawning.mesh.position.lerpVectors(spawning.startPos, spawning.targetPos, e)
        spawning.mesh.rotation.x = spawning.startRot.x * (1 - e)
        spawning.mesh.rotation.y = spawning.startRot.y * (1 - e)
        spawning.mesh.rotation.z = spawning.startRot.z * (1 - e)
        if (t >= 1) {
          bricks.push({ mesh: spawning.mesh, brickSpec: spawning.brickSpec })
          spawning = null
          lastSpawn = now
          if (shapeIndex >= currentShape.length) {
            phase = "holding"
            phaseStart = now
          }
        }
      }
    } else if (phase === "holding") {
      if (now - phaseStart >= HOLD_AFTER_BUILD_MS) {
        dismantleQueue = bricks.slice().sort((a, b) => b.brickSpec.y - a.brickSpec.y)
        phase = "dismantling"
        phaseStart = now
        lastDismantle = now - DISMANTLE_INTERVAL_MS
      }
    } else if (phase === "dismantling") {
      if (dismantleQueue.length > 0 && now - lastDismantle >= DISMANTLE_INTERVAL_MS) {
        const brick = dismantleQueue.shift()
        const angle = Math.random() * Math.PI * 2
        const radius = 13 + Math.random() * 4
        brick.exit = {
          startPos: brick.mesh.position.clone(),
          targetPos: new THREE.Vector3(
            Math.cos(angle) * radius,
            brick.mesh.position.y + 4 + Math.random() * 3,
            Math.sin(angle) * radius
          ),
          startRot: {
            x: brick.mesh.rotation.x,
            y: brick.mesh.rotation.y,
            z: brick.mesh.rotation.z,
          },
          targetRot: {
            x: (Math.random() - 0.5) * Math.PI,
            y: (Math.random() - 0.5) * Math.PI,
            z: (Math.random() - 0.5) * Math.PI,
          },
          t0: now,
        }
        lastDismantle = now
      }

      for (let i = bricks.length - 1; i >= 0; i--) {
        const brick = bricks[i]
        if (!brick.exit) continue
        const t = Math.min(1, (now - brick.exit.t0) / LEAVE_DURATION_MS)
        const e = easeInOutCubic(t)
        brick.mesh.position.lerpVectors(brick.exit.startPos, brick.exit.targetPos, e)
        brick.mesh.rotation.x =
          brick.exit.startRot.x + (brick.exit.targetRot.x - brick.exit.startRot.x) * e
        brick.mesh.rotation.y =
          brick.exit.startRot.y + (brick.exit.targetRot.y - brick.exit.startRot.y) * e
        brick.mesh.rotation.z =
          brick.exit.startRot.z + (brick.exit.targetRot.z - brick.exit.startRot.z) * e
        if (t >= 1) {
          scene.remove(brick.mesh)
          bricks.splice(i, 1)
        }
      }

      if (dismantleQueue.length === 0 && bricks.length === 0) {
        currentShape = null
        phase = "building"
        phaseStart = now
        lastSpawn = now - SPAWN_INTERVAL_MS
      }
    }

    const t = now * 0.00018
    camera.position.x = Math.cos(t) * cameraDistance
    camera.position.z = Math.sin(t) * cameraDistance
    camera.position.y = cameraHeight
    camera.lookAt(0, 0, 0)

    renderer.render(scene, camera)
  }

  function fitCanvas() {
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    if (w > 0 && h > 0) {
      renderer.setSize(w, h, false)
      camera.aspect = w / h
      camera.updateProjectionMatrix()
    }
  }
  fitCanvas()
  const ro = new ResizeObserver(fitCanvas)
  ro.observe(canvas)

  let rafId
  function loop(now) {
    step(now)
    rafId = requestAnimationFrame(loop)
  }
  rafId = requestAnimationFrame(loop)

  return () => {
    cancelAnimationFrame(rafId)
    ro.disconnect()
    renderer.dispose()
  }
}
