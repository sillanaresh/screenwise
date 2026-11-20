// Screenwise hall scene (spec section 10). Started from the prototype's Hall class.
//
// Swift owns everything around the canvas. It calls `window.hall.*` through
// callAsyncJavaScript and receives messages on the `hall` message handler:
//   { type: 'ready' } · { type: 'interactionStarted' } · { type: 'error', message }
//
// Units are feet. The origin is the floor at the bottom centre of the screen wall,
// and +z points toward the audience.

import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RectAreaLightUniformsLib } from 'three/addons/lights/RectAreaLightUniformsLib.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const post = (msg) => {
  try { window.webkit?.messageHandlers?.hall?.postMessage(msg); } catch (e) { /* not in the app */ }
};
window.addEventListener('error', (e) => post({ type: 'error', message: String(e.message || e) }));

const SCREEN_BOTTOM = 3;     // the screen's bottom edge is 3 ft above the floor
const SEAT_SPACING = 2.05;   // ft between seat centres
const SWAY_LIMIT = 0.96;     // idle sway between -55 and +55 degrees
const SWAY_SPEED = 0.0576;   // rad per second
const ease = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);

// Per theme colours (spec 10.3). Seats are one neutral colour on purpose.
const THEMES = {
  light: {
    plinth: '#e9e5df', floor: '#ddd7cf', riser: '#e2ddd6', wall: '#f4f1ec', wallIn: '#e6e1da',
    seat: '#3b3b40', mask: '#141416', hemiSky: '#ffffff', hemiGround: '#b9b2a8',
    hemi: 1.5, sun: 2.0, glow: 2.5, thumbBg: '#eceef1',
  },
  dark: {
    plinth: '#26262a', floor: '#333338', riser: '#3a3a3f', wall: '#4a4a50', wallIn: '#3e3e44',
    seat: '#5c5c63', mask: '#0b0b0c', hemiSky: '#9aa0b0', hemiGround: '#202024',
    hemi: 0.75, sun: 1.1, glow: 5, thumbBg: '#17171a',
  },
};

// One merged seat: a rounded back, a cushion and two arms. About 144 triangles.
const seatGeometry = (() => {
  const back = new RoundedBoxGeometry(1.7, 2.3, 0.4, 1, 0.16);
  back.translate(0, 2.2, 0.85);
  // RoundedBoxGeometry has no index, so the boxes drop theirs too before merging.
  const cushion = new THREE.BoxGeometry(1.7, 0.55, 1.6).toNonIndexed();
  cushion.translate(0, 1.25, 0.1);
  const armL = new THREE.BoxGeometry(0.22, 0.8, 1.7).toNonIndexed();
  armL.translate(-0.97, 1.65, 0.2);
  const armR = armL.clone();
  armR.translate(1.94, 0, 0);
  const parts = [back.index ? back.toNonIndexed() : back, cushion, armL, armR];
  for (const g of parts) g.deleteAttribute('uv');
  const merged = mergeGeometries(parts);
  if (!merged) throw new Error('Could not build the seat geometry');
  return merged;
})();

RectAreaLightUniformsLib.init();

class Hall {
  constructor(canvas, { thumbnail = false } = {}) {
    this.canvas = canvas;
    this.thumbnail = thumbnail;
    this.renderer = new THREE.WebGLRenderer({
      canvas, antialias: true, alpha: true, preserveDrawingBuffer: thumbnail,
    });
    this.renderer.setPixelRatio(thumbnail ? 1 : Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.setClearColor(0x000000, 0);

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(30, 1, 1, 5000);
    this.hemi = new THREE.HemisphereLight(0xffffff, 0xb9b2a8, 1.5);
    this.sun = new THREE.DirectionalLight(0xffffff, 2.0);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.4;
    this.glow = new THREE.RectAreaLight(0xffffff, 2.5, 10, 5);
    this.root = new THREE.Group();
    this.scene.add(this.hemi, this.sun, this.sun.target, this.glow, this.root);

    this.mode = 'hall';
    this.insets = { top: 0, bottom: 0 };  // CSS px covered by controls on the live stage
    this.viewW = 1;
    this.viewH = 1;
    this.offsetPx = 0;                    // vertical view offset, so the hall sits in the clear band
    this.reduceMotion = false;
    this.orbit = null;        // { az, pol, dist, fit } around this.target
    this.target = new THREE.Vector3();
    this.tween = null;
    this.swaying = false;
    this.swayDir = 1;
    this.interacted = false;
    this.lastTime = 0;
    this.raf = 0;
    this.visible = true;
    this.loop = this.loop.bind(this);
  }

  dispose() {
    this.root.traverse((o) => {
      if (o.geometry && o.geometry !== seatGeometry) o.geometry.dispose();
      const mats = o.material ? (Array.isArray(o.material) ? o.material : [o.material]) : [];
      for (const m of mats) { if (m.map) m.map.dispose(); m.dispose(); }
    });
    this.root.clear();
  }

  /** Builds the hall for one screen and movie. Resolves once the picture texture is ready. */
  async build(config) {
    this.config = config;
    this.dispose();
    const { screen, hall, picture, theme, accent } = config;
    const C = THEMES[theme] || THEMES.light;
    const W = screen.w;
    const Hs = screen.h;
    const roomW = Math.max(W * 1.18, W + 14);
    const roomH = SCREEN_BOTTOM + Hs + Math.max(9, Hs * 0.28);
    const depth = hall.first + hall.rows * hall.pitch + 5;
    Object.assign(this, { W, Hs, roomW, roomH, depth, hallGeo: hall });

    this.hemi.color.set(C.hemiSky);
    this.hemi.groundColor.set(C.hemiGround);
    this.baseHemi = C.hemi;
    this.baseSun = C.sun;
    this.hemi.intensity = C.hemi;
    this.sun.intensity = C.sun;
    this.thumbBg = C.thumbBg;

    const mat = (color, roughness = 0.82) => new THREE.MeshStandardMaterial({ color, roughness });
    const add = (mesh, cast = true, receive = true) => {
      mesh.castShadow = cast;
      mesh.receiveShadow = receive;
      this.root.add(mesh);
      return mesh;
    };

    // Plinth, with its top at y = 0.
    add(new THREE.Mesh(new RoundedBoxGeometry(roomW + 12, 3, depth + 12, 4, 1.4), mat(C.plinth, 0.9)))
      .position.set(0, -1.5, depth / 2);
    // Front floor, from the screen wall to the first row.
    add(new THREE.Mesh(new THREE.BoxGeometry(roomW, 0.3, hall.first + 1), mat(C.floor, 0.95)), false)
      .position.set(0, 0.15, (hall.first + 1) / 2 - 1);

    // Risers: one box per row across the room.
    const risers = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), mat(C.riser, 0.92), hall.rows);
    risers.castShadow = true;
    risers.receiveShadow = true;
    const m4 = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const v = new THREE.Vector3();
    const sc = new THREE.Vector3();
    for (let i = 0; i < hall.rows; i++) {
      const y = 0.3 + i * hall.rake;
      v.set(0, y / 2, hall.first + i * hall.pitch + hall.pitch / 2 - 1.2);
      sc.set(roomW, y, hall.pitch);
      m4.compose(v, q, sc);
      risers.setMatrixAt(i, m4);
    }
    this.root.add(risers);

    // Seats. Rows curve slightly. Seats per row are capped so the total stays close to the
    // published seat count (decision D-11).
    const fitPerRow = Math.floor((roomW - 8) / SEAT_SPACING);
    const perRow = screen.seats ? Math.max(6, Math.min(fitPerRow, Math.ceil(screen.seats / hall.rows))) : fitPerRow;
    const seats = new THREE.InstancedMesh(seatGeometry, mat(C.seat, 0.7), perRow * hall.rows);
    seats.castShadow = true;
    seats.receiveShadow = true;
    let n = 0;
    sc.set(1, 1, 1);
    for (let i = 0; i < hall.rows; i++) {
      const y = 0.3 + i * hall.rake;
      const z = hall.first + i * hall.pitch;
      const offX = ((perRow - 1) * SEAT_SPACING) / 2;
      for (let j = 0; j < perRow; j++) {
        const x = -offX + j * SEAT_SPACING;
        v.set(x, y, z + x * x * 0.0012);
        m4.compose(v, q, sc);
        seats.setMatrixAt(n++, m4);
      }
    }
    seats.count = n;
    this.root.add(seats);
    this.seatCount = n;

    // Side walls slope from full height at the screen to 6 ft at the back.
    const profile = new THREE.Shape();
    profile.moveTo(0, 0);
    profile.lineTo(depth, 0);
    profile.lineTo(depth, 6);
    profile.lineTo(0, roomH);
    profile.lineTo(0, 0);
    const wallGeo = new THREE.ExtrudeGeometry(profile, { depth: 1.6, bevelEnabled: false });
    wallGeo.rotateY(-Math.PI / 2);
    add(new THREE.Mesh(wallGeo, mat(C.wall, 0.9))).position.set(-roomW / 2, 0, 0);
    add(new THREE.Mesh(wallGeo.clone(), mat(C.wall, 0.9))).position.set(roomW / 2 + 1.6, 0, 0);
    add(new THREE.Mesh(new THREE.BoxGeometry(roomW + 3.2, roomH, 1.6), mat(C.wallIn, 0.9)))
      .position.set(0, roomH / 2, -0.8);

    // The screen surface, then the picture for this movie in front of it.
    const yc = SCREEN_BOTTOM + Hs / 2;
    this.yc = yc;
    add(new THREE.Mesh(new THREE.PlaneGeometry(W, Hs), new THREE.MeshBasicMaterial({ color: C.mask })), false, false)
      .position.set(0, yc, 0.02);
    const pw = picture.w;
    const ph = picture.h;
    const texture = await pictureTexture(picture, config.film.ratio);
    const pic = new THREE.Mesh(
      new THREE.PlaneGeometry(pw, ph),
      new THREE.MeshBasicMaterial({ map: texture, toneMapped: false }),
    );
    pic.position.set(0, yc, 0.06);
    this.root.add(pic);

    this.glow.color.set(picture.tint || '#9fb7ff');
    this.glow.width = pw;
    this.glow.height = ph;
    this.glow.position.set(0, yc, 0.4);
    this.glow.lookAt(0, yc, 40);
    this.glow.intensity = C.glow;

    // A 6 ft person for scale, 36% of the picture width left of centre, 7 ft from the screen.
    const personMat = mat(accent || '#d6363d', 0.6);
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.62, 3.1, 6, 14), personMat);
    body.position.set(-pw * 0.36, 2.8, 7);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.44, 18, 14), personMat);
    head.position.set(-pw * 0.36, 5.85, 7);
    add(body);
    add(head);

    const R = Math.max(roomW, depth);
    this.sun.position.set(-R * 0.55, R * 1.3, depth * 0.95);
    this.sun.target.position.set(0, 0, depth * 0.45);
    const sc2 = this.sun.shadow.camera;
    Object.assign(sc2, { left: -R * 0.8, right: R * 0.8, top: R * 0.8, bottom: -R * 0.8, near: 1, far: R * 4 });
    sc2.updateProjectionMatrix();

    this.center = new THREE.Vector3(0, roomH * 0.3, depth * 0.46);
    this.radius = 0.5 * Math.sqrt(roomW * roomW + depth * depth + roomH * roomH);
    return { seats: n, perRow, triangles: this.triangleCount() };
  }

  triangleCount() {
    let t = 0;
    this.root.traverse((o) => {
      if (!o.geometry) return;
      const g = o.geometry;
      const tris = (g.index ? g.index.count : g.attributes.position.count) / 3;
      t += tris * (o.isInstancedMesh ? o.count : 1);
    });
    return Math.round(t);
  }

  /** Corners that outline the model: walls, back riser and the plinth. */
  outline() {
    const { roomW, roomH, depth } = this;
    const xw = roomW / 2 + 1.6, xp = roomW / 2 + 6;
    const pts = [];
    for (const s of [-1, 1]) {
      pts.push(
        new THREE.Vector3(s * xw, roomH, -1.6), new THREE.Vector3(s * xw, 6, depth),
        new THREE.Vector3(s * xp, -3, -6), new THREE.Vector3(s * xp, -3, depth + 6),
      );
    }
    return pts;
  }

  /**
   * Camera for The hall on the live stage. Finds the closest distance at which the model stays
   * inside the clear band (below the top bar, above the controls) at every angle the hall can
   * turn to, then returns the view offset that centres it in that band. Without this the top of
   * the hall slid under the status bar and the top buttons while it turned.
   */
  fittedHallView(aspect) {
    const base = this.hallView(aspect, { sphere: true });
    const { top, bottom } = this.insets;
    const H = this.viewH;
    const bandTop = 1 - (2 * (top + 10)) / H;       // NDC, 10 px breathing room
    const bandBottom = -1 + (2 * (bottom + 6)) / H;
    const bandX = 1 - (2 * 14) / this.viewW;
    const band = bandTop - bandBottom;
    if (band <= 0.2) return { ...base, offsetPx: 0 };

    const cam = new THREE.PerspectiveCamera(base.fov, aspect, 1, 20000);
    const pts = this.outline();
    const dir0 = base.pos.clone().sub(base.target).normalize();
    const pol = Math.acos(THREE.MathUtils.clamp(dir0.y, -1, 1));
    const angles = [-1.05, -0.7, -0.35, 0, 0.35, 0.62, 0.7, 1.05];
    const v = new THREE.Vector3();
    const extent = (d) => {
      let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
      for (const az of angles) {
        cam.position.set(Math.sin(pol) * Math.sin(az), Math.cos(pol), Math.sin(pol) * Math.cos(az))
          .multiplyScalar(d).add(base.target);
        cam.lookAt(base.target);
        cam.updateMatrixWorld();
        for (const p of pts) {
          v.copy(p).project(cam);
          x0 = Math.min(x0, v.x); x1 = Math.max(x1, v.x); y0 = Math.min(y0, v.y); y1 = Math.max(y1, v.y);
        }
      }
      return { x0, x1, y0, y1 };
    };
    const fits = (e) => e.y1 - e.y0 <= band && e.x0 >= -bandX && e.x1 <= bandX;
    let lo = this.radius * 0.8, hi = this.radius * 12;
    for (let i = 0; i < 28; i++) {
      const mid = (lo + hi) / 2;
      if (fits(extent(mid))) hi = mid; else lo = mid;
    }
    const e = extent(hi);
    // Move the model's vertical middle to the band's middle. In three.js a positive view
    // offset moves the picture up, so a downward shift (negative in NDC) is a negative offset.
    const shiftNdc = (bandTop + bandBottom) / 2 - (e.y0 + e.y1) / 2;
    const pos = dir0.multiplyScalar(hi).add(base.target);
    return { pos, target: base.target, fov: base.fov, offsetPx: (shiftNdc * H) / 2 };
  }

  setOffset(px) {
    this.offsetPx = px;
    if (Math.abs(px) < 0.5) this.camera.clearViewOffset();
    else this.camera.setViewOffset(this.viewW, this.viewH, 0, px, this.viewW, this.viewH);
    this.camera.updateProjectionMatrix();
  }

  /** Camera for The hall: fits the room's bounding sphere (spec 10.4). Used for thumbnails. */
  hallView(aspect, { sphere = false } = {}) {
    if (!sphere && !this.thumbnail && this.viewH > 1) return this.fittedHallView(aspect);
    const vf = THREE.MathUtils.degToRad(30);
    const hf = 2 * Math.atan(Math.tan(vf / 2) * aspect);
    // The live stage loses its lower part to the controls and the sheet, so it keeps a
    // little more margin than the card thumbnails.
    const margin = this.thumbnail ? 1.0 : 1.16;
    const d = (this.radius / Math.sin(Math.min(vf, hf) / 2)) * margin;
    const az = 0.62;
    const pol = 0.98;
    const pos = new THREE.Vector3(Math.sin(pol) * Math.sin(az), Math.cos(pol), Math.sin(pol) * Math.cos(az))
      .multiplyScalar(d).add(this.center);
    const target = this.center.clone();
    target.y -= this.roomH * 0.12;
    return { pos, target, fov: 30 };
  }

  /** Camera for From your seat: eye 4 ft above the riser, 0.25 ft behind the row line. */
  seatView(row) {
    const h = this.hallGeo;
    const z = h.first + row * h.pitch + 0.25;
    const y = 0.3 + row * h.rake + 4.0;
    return { pos: new THREE.Vector3(0, y, z), target: new THREE.Vector3(0, this.yc - 1.5, 0), fov: 52 };
  }

  setSize(width, height) {
    this.renderer.setSize(width, height, false);
    this.viewW = Math.max(1, width);
    this.viewH = Math.max(1, height);
    this.camera.aspect = width / Math.max(1, height);
    this.setOffset(this.mode === 'hall' ? this.offsetPx : 0);
    if (this.mode === 'hall' && !this.tween && this.orbit) this.applyOrbit();
    this.requestRender();
  }

  // Orbit state, kept as spherical coordinates around the target.
  orbitFrom(pos, target) {
    const off = pos.clone().sub(target);
    const dist = off.length();
    return {
      az: Math.atan2(off.x, off.z),
      pol: Math.acos(THREE.MathUtils.clamp(off.y / dist, -1, 1)),
      dist,
      fit: dist,
      azVel: 0,
    };
  }

  applyOrbit() {
    const o = this.orbit;
    const s = new THREE.Vector3(
      Math.sin(o.pol) * Math.sin(o.az), Math.cos(o.pol), Math.sin(o.pol) * Math.cos(o.az),
    ).multiplyScalar(o.dist);
    this.camera.position.copy(this.target).add(s);
    this.camera.lookAt(this.target);
  }

  flyTo(view, ms) {
    const cam = this.camera;
    this.tween = {
      t0: performance.now(), ms: this.reduceMotion ? 1 : ms,
      p0: cam.position.clone(), p1: view.pos.clone(),
      tg0: this.target.clone(), tg1: view.target.clone(),
      f0: cam.fov, f1: view.fov,
      o0: this.offsetPx, o1: view.offsetPx ?? 0,
      d0: this.dimLevel ?? 0, d1: this.mode === 'seat' ? 1 : 0,
    };
    this.requestRender();
  }

  setMode(mode, { instant = false, row = 0 } = {}) {
    this.mode = mode;
    if (mode === 'hall') {
      const view = this.hallView(this.camera.aspect);
      this.orbit = this.orbitFrom(view.pos, view.target);
      if (instant) {
        // Fly in from 1.25 times the distance over 1.1 s.
        const start = view.pos.clone().sub(view.target).multiplyScalar(1.25).add(view.target);
        this.camera.position.copy(start);
        this.target.copy(view.target);
        this.camera.fov = view.fov;
        this.setOffset(view.offsetPx ?? 0);
        this.hemi.intensity = this.baseHemi;
        this.sun.intensity = this.baseSun;
        this.dimLevel = 0;
        this.flyTo(view, 1100);
      } else {
        this.flyTo(view, 1200);
      }
      this.swaying = !this.reduceMotion && !this.interacted && !this.thumbnail;
    } else {
      this.swaying = false;
      this.flyTo(this.seatView(row), instant ? 1200 : 1200);
    }
  }

  setRow(row) {
    if (this.mode !== 'seat') return;
    this.flyTo(this.seatView(row), 600);
  }

  /** Turns the hall by a drag delta in points. Driven by SwiftUI gestures. */
  rotate(dxPoints) {
    if (this.mode !== 'hall' || !this.orbit) return;
    this.noteInteraction();
    if (this.tween) this.finishTween();
    const o = this.orbit;
    o.az = THREE.MathUtils.clamp(o.az - dxPoints * 0.006, -1.05, 1.05);
    o.azVel = -dxPoints * 0.006;
    this.applyOrbit();
    this.requestRender();
  }

  /** Zooms by a pinch scale, between 0.55 and 1.5 times the fitted distance. */
  zoom(scale) {
    if (this.mode !== 'hall' || !this.orbit) return;
    this.noteInteraction();
    const o = this.orbit;
    if (o.pinchStart == null) o.pinchStart = o.dist;
    o.dist = THREE.MathUtils.clamp(o.pinchStart / scale, o.fit * 0.55, o.fit * 1.5);
    this.applyOrbit();
    this.requestRender();
  }

  endGesture() {
    if (this.orbit) this.orbit.pinchStart = null;
    this.requestRender();
  }

  noteInteraction() {
    if (!this.interacted) {
      this.interacted = true;
      post({ type: 'interactionStarted' });
    }
    this.swaying = false;
  }

  finishTween() {
    const t = this.tween;
    if (!t) return;
    this.camera.position.copy(t.p1);
    this.target.copy(t.tg1);
    this.camera.fov = t.f1;
    this.setOffset(t.o1);
    this.tween = null;
    if (this.mode === 'hall') this.orbit = { ...this.orbitFrom(t.p1, t.tg1), fit: this.orbit?.fit ?? t.p1.distanceTo(t.tg1) };
  }

  requestRender() {
    if (!this.raf && this.visible) this.raf = requestAnimationFrame(this.loop);
  }

  loop(now) {
    this.raf = 0;
    this.frames = (this.frames || 0) + 1;
    const dt = this.lastTime ? Math.min(0.05, (now - this.lastTime) / 1000) : 0.016;
    this.lastTime = now;
    let animating = false;

    if (this.tween) {
      const t = this.tween;
      const k = Math.min(1, (now - t.t0) / t.ms);
      const e = ease(k);
      this.camera.position.lerpVectors(t.p0, t.p1, e);
      this.target.lerpVectors(t.tg0, t.tg1, e);
      this.camera.fov = t.f0 + (t.f1 - t.f0) * e;
      this.setOffset(t.o0 + (t.o1 - t.o0) * e);
      this.camera.lookAt(this.target);
      // In the seat view the lights dim so the picture glows.
      this.dimLevel = t.d0 + (t.d1 - t.d0) * e;
      this.setDim(this.dimLevel);
      if (k >= 1) this.finishTween();
      animating = true;
    } else if (this.mode === 'hall' && this.orbit) {
      const o = this.orbit;
      if (this.swaying) {
        if (o.az > SWAY_LIMIT) this.swayDir = -1;
        else if (o.az < -SWAY_LIMIT) this.swayDir = 1;
        o.az += this.swayDir * SWAY_SPEED * dt;
        animating = true;
      } else if (Math.abs(o.azVel) > 0.0004) {
        // Damping after a drag (0.08 per frame, as in the prototype's controls).
        o.azVel *= 0.92;
        o.az = THREE.MathUtils.clamp(o.az + o.azVel * 0.35, -1.05, 1.05);
        animating = true;
      }
      this.applyOrbit();
    }

    this.renderer.render(this.scene, this.camera);
    if (animating) this.requestRender();
    else this.lastTime = 0;
  }

  setDim(level) {
    this.hemi.intensity = this.baseHemi * (1 - 0.72 * level);
    this.sun.intensity = this.baseSun * (1 - 0.85 * level);
  }

  /** Renders The hall view at w × h and returns a JPEG data URL (for card thumbnails). */
  snapshot(w, h) {
    const prevAspect = this.camera.aspect;
    this.camera.clearViewOffset();
    this.renderer.setPixelRatio(1);
    this.renderer.setSize(w, h, false);
    this.renderer.setClearColor(new THREE.Color(this.thumbBg), 1);
    const view = this.hallView(w / h, { sphere: true });
    this.camera.aspect = w / h;
    this.camera.position.copy(view.pos);
    this.camera.fov = view.fov;
    this.camera.updateProjectionMatrix();
    this.camera.lookAt(view.target);
    this.setDim(0);
    this.renderer.render(this.scene, this.camera);
    const url = this.canvas.toDataURL('image/jpeg', 0.86);
    this.renderer.setClearColor(0x000000, 0);
    this.camera.aspect = prevAspect;
    this.setOffset(this.offsetPx);
    return url;
  }
}

/** Draws the movie image into a canvas cropped to the movie's frame. */
async function pictureTexture(picture, ratio) {
  const cv = document.createElement('canvas');
  cv.width = 1024;
  cv.height = Math.round(1024 / ratio);
  const ctx = cv.getContext('2d');
  let img = null;
  if (picture.image) {
    img = await new Promise((resolve) => {
      const im = new Image();
      im.onload = () => resolve(im);
      im.onerror = () => resolve(null);
      im.src = picture.image;
    });
  }
  if (img) {
    const ir = img.width / img.height;
    const tr = cv.width / cv.height;
    let sw = img.width, sh = img.height, sx = 0, sy = 0;
    if (ir > tr) { sw = img.height * tr; sx = (img.width - sw) / 2; } else { sh = img.width / tr; sy = (img.height - sh) / 2; }
    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, cv.width, cv.height);
  } else {
    ctx.fillStyle = picture.tint || '#9fb7ff';
    ctx.fillRect(0, 0, cv.width, cv.height);
  }
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

// ---------------------------------------------------------------- bridge

const canvas = document.getElementById('hall');
const params = new URLSearchParams(location.search);
let hall = null;
try {
  hall = new Hall(canvas, { thumbnail: params.get('mode') === 'thumbnail' });
} catch (e) {
  post({ type: 'error', message: 'WebGL is not available: ' + e.message });
}

const fit = () => hall && hall.setSize(window.innerWidth, window.innerHeight);
window.addEventListener('resize', fit);

// Pointer dragging, for testing in a browser. In the app SwiftUI sends rotate() instead.
let dragX = null;
canvas.addEventListener('pointerdown', (e) => { dragX = e.clientX; });
window.addEventListener('pointermove', (e) => {
  if (dragX == null || !hall) return;
  hall.rotate(e.clientX - dragX);
  dragX = e.clientX;
});
window.addEventListener('pointerup', () => { dragX = null; hall?.endGesture(); });

window.hall = {
  async build(config) {
    if (!hall) throw new Error('WebGL is not available');
    hall.reduceMotion = !!config.reduceMotion;
    hall.interacted = false;
    if (config.insets) hall.insets = { top: config.insets.top || 0, bottom: config.insets.bottom || 0 };
    const info = await hall.build(config);
    if (!hall.thumbnail) {
      fit();
      hall.setMode(config.mode || 'hall', { instant: true, row: config.row || 0 });
    }
    return info;
  },
  async setTheme(theme, accent) {
    if (!hall?.config) return;
    const mode = hall.mode;
    const row = hall.row || 0;
    await hall.build({ ...hall.config, theme, accent: accent || hall.config.accent });
    hall.dimLevel = mode === 'seat' ? 1 : 0;
    if (mode === 'seat') { hall.setDim(1); hall.mode = 'seat'; const v = hall.seatView(row); hall.camera.position.copy(v.pos); hall.target.copy(v.target); hall.camera.fov = v.fov; hall.setOffset(0); hall.camera.lookAt(v.target); }
    hall.requestRender();
  },
  setMode(mode, row) { hall.row = row || 0; hall?.setMode(mode, { row: row || 0 }); },
  setRow(row) { hall.row = row; hall?.setRow(row); },
  rotate(dx) { hall?.rotate(dx); },
  zoom(scale) { hall?.zoom(scale); },
  endGesture() { hall?.endGesture(); },
  setVisible(visible) { if (!hall) return; hall.visible = visible; if (visible) hall.requestRender(); },
  snapshot(w, h) { return hall ? hall.snapshot(w, h) : null; },
  triangles() { return hall ? hall.triangleCount() : 0; },
  debugState() {
    if (!hall) return null;
    const c = hall.camera.position;
    return { frames: hall.frames || 0, visible: hall.visible, mode: hall.mode, tween: !!hall.tween,
      canvas: [canvas.width, canvas.height], cam: [c.x, c.y, c.z].map((v) => Math.round(v)),
      vis: document.visibilityState };
  },
};

post({ type: 'ready', webgl: !!hall });
