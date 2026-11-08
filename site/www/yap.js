// yap, on a web page. The geometry, springs and timings are ported from Sources/Yap/Pill.swift (the glass,
// the Pulse, the Said text), Caret.swift (where the panel sits by the cursor) and App.swift (keys, timings, and
// the dot that grows at the caret and shrinks back before the blob returns), so it moves the way the app does.
(() => {
  'use strict';

  const $ = (s) => document.querySelector(s);
  const motionQuery = matchMedia('(prefers-reduced-motion: reduce)');
  let still = motionQuery.matches;
  motionQuery.addEventListener('change', (e) => { still = e.matches; wake(); });

  // ---------- springs: SwiftUI's .spring(response:dampingFraction:) ----------
  const PHASE = [0.52, 0.86], HOVER = [0.48, 0.86], LEVEL = [0.28, 0.86], DRIP = [0.65, 0.86],
        TEXT = [0.24, 1], DROP = [0.38, 0.65], PULSE = [0.35, 0.9], BUBBLE = [0.3, 0.9];

  class Spring {
    constructor(v) { this.v = v; this.t = v; this.vel = 0; this.r = 0.5; this.z = 0.86; }
    to(t, cfg) { if (t === this.t) return; this.t = t; this.r = cfg[0]; this.z = cfg[1]; if (still) this.jump(t); }
    jump(t) { this.v = this.t = t; this.vel = 0; }
    step(dt) {
      const w = 2 * Math.PI / this.r, a = -w * w * (this.v - this.t) - 2 * this.z * w * this.vel;
      this.vel += a * dt; this.v += this.vel * dt;
    }
    get resting() { return Math.abs(this.v - this.t) < 0.002 && Math.abs(this.vel) < 0.002; }
  }

  const S = {
    width: new Spring(12), height: new Spring(44), corner: new Spring(6), orb: new Spring(0),
    chip: new Spring(0), chipGap: new Spring(0), level: new Spring(0), pulse: new Spring(0),
    stretch: new Spring(1), ox: new Spring(0), oy: new Spring(0),
  };

  const ORB = 38;
  // Caret.Bubble: at the caret the panel is a small bubble sized from the line it's on. 13 to 15 pt text,
  // hugging the words up to 400 wide, then up to three lines with the oldest fading off the top.
  // (A phone's screen is narrower than 400, so there it's the screen less a margin.)
  function bubbleFor(lineHeight) {
    const font = Math.min(15, Math.max(13, Math.round(lineHeight / 1.25) + 1));
    const line = Math.ceil(font * 1.2), pad = 7, trail = 13, widest = Math.min(400, innerWidth - 16);
    const single = line + 2 * pad, tallest = line * 3 + 1 + 2 * pad, textX = single - 2;
    return {
      font, line, pad, single, tallest, textX, textWidest: widest - textX - trail, widest,
      // A clear gap from the caret's line, 6 to 14 by line height.
      gap: Math.min(14, Math.max(6, Math.round(lineHeight * 0.4))),
      shown: (h) => Math.max(0, Math.min(h, line * 3 + 1)),
      width(t) { return Math.min(widest, Math.max(single, textX + t.w + trail)); },
      height(t) { return Math.max(single, this.shown(t.h) + 2 * pad); },
    };
  }

  // ---------- state, as in Dictation ----------
  const st = {
    phase: 'hidden', // hidden, listening, finishing, done
    open: false, anchor: 'blob', above: false,
    hovering: false, armed: false, dragging: false, pressed: false, locked: false,
    settled: '', guessing: '', level: 0, dripped: false,
    edge: 'right', slide: 0, pull: { x: 0, y: 0 }, textHeight: 34,
    bubble: bubbleFor(18), text: { w: 0, h: 18 },
  };

  const coarse = matchMedia('(pointer: coarse)').matches;
  try {
    const saved = JSON.parse(localStorage.getItem('yap-spot') || 'null');
    if (saved && ['right', 'left', 'bottom'].includes(saved.edge)) { st.edge = saved.edge; st.slide = saved.slide || 0; }
  } catch (_) {}
  const narrow = () => innerWidth < 761;
  const edgeNow = () => (narrow() || coarse ? 'bottom' : st.edge);
  const atCaret = () => st.anchor === 'caret';
  const talking = () => st.open && (st.phase === 'listening' || st.phase === 'finishing');
  const clamp = (x, lo, hi) => Math.max(lo, Math.min(x, Math.max(lo, hi)));

  const panelWidth = () => {
    const room = edgeNow() === 'bottom' ? innerWidth - 20 : innerWidth - 20 - ORB - 16;
    return Math.max(220, Math.min(496, room));
  };

  function targets(cause) {
    const e = edgeNow(), ex = st.open;
    if (atCaret()) {
      // A bubble that grows out of a dot under the caret: right as the words come, then a line at a time.
      const b = st.bubble;
      S.width.to(ex ? b.width(st.text) : b.single, cause);
      S.height.to(ex ? b.height(st.text) : b.single, cause);
      S.corner.to(b.single / 2, cause);
      S.orb.to(0, cause); S.chip.to(0, cause); S.chipGap.to(0, DRIP);
      wake();
      return;
    }
    S.width.to(ex ? panelWidth() : st.hovering ? 184 : e === 'bottom' ? 44 : 12, cause);
    S.height.to(ex ? Math.max(34, st.textHeight) + 44 : st.hovering ? 40 : e === 'bottom' ? 12 : 44, cause);
    S.corner.to(ex ? 26 : st.hovering ? 20 : 6, cause);
    S.orb.to(talking() ? 1 : 0, cause);
    S.chip.to(st.phase === 'done' ? 1 : 0, cause);
    S.chipGap.to(still || st.dripped ? 24 : 0, DRIP);
    wake();
  }

  // ---------- where the caret is ----------
  const caret = document.createElement('span');
  caret.className = 'caret'; caret.setAttribute('aria-hidden', 'true');
  const firstSlot = $('#talk [data-slot]') || $('[data-slot]');
  firstSlot.appendChild(caret);
  // At the start of a dictation a mark goes where the caret is, so the panel stays put while the paste pushes the caret on.
  let marker = null;
  function dropMarker() { if (marker) marker.remove(); marker = document.createElement('span'); marker.className = 'anchor'; caret.before(marker); }
  function liftMarker() { if (marker) { marker.remove(); marker = null; } }
  function anchorRect() {
    const r = (marker || caret).getBoundingClientRect();
    if (r.height > 1) return r;
    const c = caret.getBoundingClientRect();
    return { left: r.left || c.left, right: r.left || c.right, top: c.top, bottom: c.bottom, height: c.height, width: 0 };
  }
  // On screen, and not scrolled out of a column or the strip.
  function visible(el) {
    const r = el.getBoundingClientRect();
    if (!r.height) return false;
    let top = r.top, bottom = r.bottom, left = r.left, right = r.right;
    for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
      const cs = getComputedStyle(p);
      if (cs.overflowX === 'visible' && cs.overflowY === 'visible') continue;
      const q = p.getBoundingClientRect();
      top = Math.max(top, q.top); bottom = Math.min(bottom, q.bottom); left = Math.max(left, q.left); right = Math.min(right, q.right);
    }
    return bottom - top > r.height * 0.6 && right >= left && top >= 0 && bottom <= innerHeight && left >= 0 && right <= innerWidth;
  }

  // ---------- geometry: LiquidOutline in viewport points ----------
  const K = 0.5523;
  function mainFrame() {
    const e = edgeNow(), w = Math.max(1, S.width.v), h = Math.max(1, S.height.v), vw = innerWidth, vh = innerHeight;
    if (atCaret()) {
      // Caret.place: the leading cap (and the light in it) under the caret, the bubble growing right from there
      // unless the edge is near; a gap under the line, or over it when there's no room below for three lines.
      const r = anchorRect(), b = st.bubble;
      const x = clamp(r.left - b.single / 2, 8, vw - 8 - b.widest);
      const y = st.above ? clamp(r.top - b.gap, 8 + b.tallest, vh - 8) - h : clamp(r.bottom + b.gap, 8, vh - 8 - b.tallest);
      return { x: x + S.ox.v, y: y + S.oy.v, w, h };
    }
    const inset = 8;
    let x, y;
    if (e === 'bottom') {
      x = (vw - w) / 2 + st.slide; y = vh - inset - h - 54 * Math.max(0, S.chip.v);
    } else {
      x = e === 'right' ? vw - inset - w : inset;
      y = vh / 2 - st.slide - h / 2;
    }
    x = Math.min(Math.max(x, 10), vw - 10 - w);
    y = Math.min(Math.max(y, 10), vh - 10 - h);
    return { x: x + S.ox.v, y: y + S.oy.v, w, h };
  }
  const side = () => edgeNow();
  const orbGap = () => (still ? 4 : 1 + 10 * Math.min(Math.max(S.level.v, 0), 1));
  function orbFrame(m) {
    const e = side(), d = ORB * Math.max(0, S.orb.v), gap = orbGap();
    if (e === 'bottom') return { x: m.x + m.w / 2 - d / 2, y: m.y - gap - d, w: d, h: d };
    return { x: e === 'right' ? m.x - gap - d : m.x + m.w + gap, y: m.y + m.h / 2 - d / 2, w: d, h: d };
  }
  const chipsUp = () => false;
  function chipFrame(m) {
    const a = Math.max(0, S.chip.v), gap = Math.max(0, S.chipGap.v);
    const y = chipsUp() ? m.y - gap - 30 * a : m.y + m.h + gap;
    return { x: m.x + m.w / 2 - 49 * a, y, w: 98 * a, h: 30 * a };
  }

  // Each subpath is made clockwise so overlaps union under nonzero.
  function roundRect(f, r) {
    r = Math.max(0, Math.min(r, f.w / 2, f.h / 2));
    const { x, y, w, h } = f, k = r * K;
    return { start: [x + r, y], segs: [
      ['L', [x + w - r, y]], ['C', [x + w - r + k, y], [x + w, y + r - k], [x + w, y + r]],
      ['L', [x + w, y + h - r]], ['C', [x + w, y + h - r + k], [x + w - r + k, y + h], [x + w - r, y + h]],
      ['L', [x + r, y + h]], ['C', [x + r - k, y + h], [x, y + h - r + k], [x, y + h - r]],
      ['L', [x, y + r]], ['C', [x, y + r - k], [x + r - k, y], [x + r, y]],
    ] };
  }
  const ellipse = (f) => roundRect(f, f.w / 2);
  const mapSub = (p, fn) => ({ start: fn(p.start), segs: p.segs.map((s) => [s[0], ...s.slice(1).map(fn)]) });
  function area(p) {
    const pts = [p.start, ...p.segs.flatMap((s) => s.slice(1))];
    let a = 0;
    for (let i = 0; i < pts.length; i++) { const [x1, y1] = pts[i], [x2, y2] = pts[(i + 1) % pts.length]; a += x1 * y2 - x2 * y1; }
    return a / 2;
  }
  function reverse(p) {
    const pts = [p.start, ...p.segs.map((s) => s[s.length - 1])];
    const segs = [];
    for (let i = p.segs.length - 1; i >= 0; i--) {
      const s = p.segs[i], to = pts[i];
      segs.push(s[0] === 'L' ? ['L', to] : ['C', s[2], s[1], to]);
    }
    return { start: pts[pts.length - 1], segs };
  }
  const clockwise = (p) => (area(p) < 0 ? reverse(p) : p);
  function toD(subs, dx = 0, dy = 0) {
    const f = (pt) => `${(pt[0] - dx).toFixed(2)} ${(pt[1] - dy).toFixed(2)}`;
    return subs.map((p) => `M${f(p.start)}` + p.segs.map((s) => s[0] + s.slice(1).map(f).join(' ')).join('') + 'Z').join('');
  }
  // A flat edge at x=0 meeting the facing arc of a round bud, as in circleBridge.
  function circleBridge(r, gap, flatHalf) {
    const amount = Math.sqrt(Math.max(0, 1 - gap / 16));
    const theta = Math.PI * 0.42 * amount;
    const a = Math.min((r + 9 * Math.max(0, S.orb.v)) * amount, Math.max(0.5, flatHalf - 0.5));
    const x = gap + r - r * Math.cos(theta), y = r * Math.sin(theta);
    const handle = Math.min(x * 0.65, (y * 0.45) / Math.max(0.1, Math.cos(theta)));
    return { start: [-0.5, -a], segs: [
      ['C', [-0.5, -a * 0.3], [x - handle * Math.sin(theta), -y + handle * Math.cos(theta)], [x, -y]],
      ['L', [gap + r, 0]], ['L', [x, y]],
      ['C', [x - handle * Math.sin(theta), y - handle * Math.cos(theta)], [-0.5, a * 0.3], [-0.5, a]],
    ] };
  }

  function outline() {
    const m = mainFrame(), e = side();
    const corner = Math.max(0, Math.min(S.corner.v, Math.min(m.w, m.h) / 2));
    let main = roundRect(m, corner);
    const s = S.stretch.v;
    if (Math.abs(s - 1) > 0.001) {
      // Longer along the pull, thinner across it.
      const cx = m.x + m.w / 2, cy = m.y + m.h / 2, a = Math.atan2(st.pull.y, st.pull.x), c = Math.cos(a), sn = Math.sin(a);
      const sy = 1 / Math.sqrt(s);
      main = mapSub(main, ([px, py]) => {
        const dx = px - cx, dy = py - cy;
        const u = (dx * c + dy * sn) * s, v = (-dx * sn + dy * c) * sy;
        return [cx + u * c - v * sn, cy + u * sn + v * c];
      });
    }
    const subs = [clockwise(main)];
    const o = orbFrame(m), ch = chipFrame(m);
    if (S.orb.v > 0.001) {
      subs.push(clockwise(ellipse(o)));
      const gap = orbGap();
      if (gap < 16) {
        const flatHalf = (e === 'bottom' ? m.w : m.h) / 2 - corner;
        let fn;
        if (e === 'bottom') fn = ([x, y]) => [y + m.x + m.w / 2, -x + m.y];
        else if (e === 'right') fn = ([x, y]) => [-x + m.x, y + m.y + m.h / 2];
        else fn = ([x, y]) => [x + m.x + m.w, y + m.y + m.h / 2];
        subs.push(clockwise(mapSub(circleBridge(o.w / 2, gap, flatHalf), fn)));
      }
    }
    if (S.chip.v > 0.001) {
      subs.push(clockwise(roundRect(ch, ch.h / 2)));
      const gap = Math.max(0, S.chipGap.v);
      if (gap < 16) {
        const amount = Math.sqrt(Math.max(0, 1 - gap / 16));
        const a = (ch.w / 2 + 10) * amount, b = ((ch.w - ch.h) / 2) * amount;
        const up = chipsUp();
        const x = ch.x + ch.w / 2, top = up ? m.y + 0.5 : m.y + m.h - 0.5, bottom = up ? ch.y + ch.h - 0.5 : ch.y + 0.5;
        subs.push(clockwise({ start: [x + a, top], segs: [
          ['C', [x + a * 0.15, top], [x + b * 0.15, bottom], [x + b, bottom]],
          ['L', [x - b, bottom]],
          ['C', [x - b * 0.15, bottom], [x - a * 0.15, top], [x - a, top]],
        ] }));
      }
    }
    return { subs, m, o, ch };
  }

  // ---------- drawing ----------
  const box = $('#yap'), glass = $('#yap-glass'), canvas = $('#yap-edge'), ctx = canvas.getContext('2d');
  const saidEl = $('#yap-said'), hintEl = $('#yap-hint'), orbEl = $('#yap-orb'), ringEl = $('#yap-ring'), dotEl = $('#yap-dot');
  const chipEl = $('#yap-chip'), hit = $('#yap-hit'), fnKey = $('#fn-key'), status = $('#status');
  const lightEl = $('#yap-light'), lightRing = $('#yap-light-ring'), lightDot = $('#yap-light-dot');
  const darkQ = matchMedia('(prefers-color-scheme: dark)');
  darkQ.addEventListener('change', () => wake());
  let dpr = 1;
  function sizeCanvas() {
    dpr = Math.min(2, devicePixelRatio || 1);
    canvas.width = innerWidth * dpr; canvas.height = innerHeight * dpr;
  }
  sizeCanvas();
  let lastFrame = null, controlHovered = false, overOrb = false;

  function draw(now) {
    const { subs, m, o, ch } = outline();
    const xs = subs.flatMap((p) => [p.start[0], ...p.segs.flatMap((s) => s.slice(1).map((q) => q[0]))]);
    const ys = subs.flatMap((p) => [p.start[1], ...p.segs.flatMap((s) => s.slice(1).map((q) => q[1]))]);
    const bx = Math.floor(Math.min(...xs)) - 2, by = Math.floor(Math.min(...ys)) - 2;
    const bw = Math.ceil(Math.max(...xs)) + 2 - bx, bh = Math.ceil(Math.max(...ys)) + 2 - by;
    glass.style.transform = `translate(${bx}px, ${by}px)`;
    glass.style.width = bw + 'px'; glass.style.height = bh + 'px';
    glass.style.clipPath = `path('${toD(subs, bx, by)}')`;

    // Contents, in the glass's own box. The clip-path masks them like .mask(shape).
    const c = atCaret(), b = st.bubble, light = !darkQ.matches;
    glass.classList.toggle('at-caret', c);
    canvas.classList.toggle('at-caret', c);
    if (c) {
      // The words start past the leading cap; on the line nearest the caret, the newest at the bottom.
      const shown = b.shown(st.text.h);
      saidEl.style.left = m.x - bx + b.textX + 'px';
      saidEl.style.top = (st.above ? m.y + m.h - b.pad - shown : m.y + b.pad) - by + 'px';
      saidEl.style.height = shown + 'px';
      // The recording light, in the cap under the caret.
      lightEl.style.left = m.x - bx + b.single / 2 - 19 + 'px';
      lightEl.style.top = (st.above ? m.y + m.h - b.single / 2 : m.y + b.single / 2) - by - 19 + 'px';
      lightEl.style.opacity = st.phase === 'listening' || st.phase === 'finishing' ? 1 : 0;
      const l = Math.min(Math.max(S.pulse.v, 0), 1), k = 0.62;
      const ring = (still ? 22 : 14 + 14 * l) * k, dot = (still ? 11 : 10 + 3 * l) * k;
      lightRing.style.width = lightRing.style.height = ring + 'px';
      lightRing.style.opacity = still ? 0.15 + 0.6 * l : 0.12 + 0.45 * l;
      lightDot.style.width = lightDot.style.height = dot + 'px';
    } else {
      saidEl.style.left = m.x - bx + 28 + 'px';
      saidEl.style.top = m.y - by + (m.h - st.textHeight) / 2 + 'px';
      saidEl.style.height = '';
      lightEl.style.opacity = 0;
    }
    hintEl.style.display = !st.open && st.hovering ? '' : 'none';
    hintEl.style.left = m.x - bx + 'px'; hintEl.style.width = m.w + 'px';
    hintEl.style.top = m.y - by + m.h / 2 - 7.5 + 'px';
    hintEl.style.opacity = Math.max(0, Math.min(1, (S.width.v - 60) / 100));
    orbEl.style.left = o.x - bx + o.w / 2 - 19 + 'px'; orbEl.style.top = o.y - by + o.h / 2 - 19 + 'px';
    orbEl.style.opacity = Math.min(1, Math.max(0, S.orb.v));
    orbEl.style.background = st.pressed && talking() ? 'rgba(255,255,255,.25)' : overOrb ? 'rgba(255,255,255,.18)' : 'transparent';
    // Pulse: a dot with a soft ring that swells as you talk. Reduce motion: nothing changes size, the ring brightens.
    const l = Math.min(Math.max(S.pulse.v, 0), 1);
    const ring = still ? 22 : 14 + 14 * l, dot = still ? 11 : 10 + 3 * l;
    ringEl.style.width = ringEl.style.height = ring + 'px';
    ringEl.style.borderColor = `rgba(255,255,255,${still ? 0.15 + 0.6 * l : 0.12 + 0.45 * l})`;
    dotEl.style.width = dotEl.style.height = dot + 'px';
    chipEl.style.left = ch.x - bx + ch.w / 2 - 49 + 'px'; chipEl.style.width = '98px';
    chipEl.style.top = ch.y - by + ch.h / 2 - 15 + 'px'; chipEl.style.height = '30px';
    chipEl.style.opacity = Math.min(1, Math.max(0, S.chip.v));
    const press = st.pressed && !talking() ? 0.22 : controlHovered ? (c ? 0.08 : 0.13) : 0;
    const ink = c && light ? '0,0,0' : '255,255,255';
    glass.style.boxShadow = press ? `inset 0 0 0 999px rgba(${ink},${press})` : 'none';

    // The edge: a hairline round the union, plus the light that goes round it while it's open.
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const path = new Path2D(toD(subs));
    ctx.globalCompositeOperation = 'source-over';
    // At the caret: a finer, quieter edge in the system's own ink, and the moving light at about half.
    ctx.lineWidth = c ? 1.2 : 1.6;
    ctx.strokeStyle = c ? `rgba(${ink},${controlHovered ? 0.4 : light ? 0.12 : 0.2})` : `rgba(255,255,255,${controlHovered ? 0.65 : 0.3})`;
    ctx.stroke(path);
    ctx.globalAlpha = c ? 0.55 : 1;
    const moving = !still && (st.open || st.hovering);
    const angle = (moving ? ((now / 1000) % 6) * 60 : 225) * Math.PI / 180;
    if (ctx.createConicGradient) {
      const g = ctx.createConicGradient(angle, m.x + m.w / 2, m.y + m.h / 2);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.4, 'rgba(255,255,255,0)');
      g.addColorStop(0.48, 'rgba(255,255,255,.9)'); g.addColorStop(0.51, 'rgba(255,255,255,.45)');
      g.addColorStop(0.59, 'rgba(255,255,255,0)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.lineWidth = c ? 2 : 2.4; ctx.strokeStyle = g; ctx.stroke(path);
    }
    ctx.globalAlpha = 1;
    // Keep only the outside half of the strokes, so the union's inner seams never show.
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fill(path);
    ctx.globalCompositeOperation = 'source-over';

    // The button that takes the pointer and focus sits on the blob, or on the panel while you talk.
    // The seed at the caret is only ever passing through, so it's never something to click.
    // At the caret the whole bubble is the button (hands free, click it to paste).
    const pad = 4, withOrb = talking() && !c;
    const hx = Math.min(m.x, withOrb ? o.x : m.x) - pad, hy = Math.min(m.y, withOrb ? o.y : m.y) - pad;
    const hx2 = Math.max(m.x + m.w, withOrb ? o.x + o.w : 0) + pad, hy2 = Math.max(m.y + m.h, withOrb ? o.y + o.h : 0) + pad;
    const live = (st.phase === 'hidden' && !atCaret()) || (st.phase === 'listening' && st.open);
    hit.style.display = live ? '' : 'none';
    hit.style.transform = `translate(${hx}px, ${hy}px)`;
    hit.style.width = hx2 - hx + 'px'; hit.style.height = hy2 - hy + 'px';
    hit.style.borderRadius = Math.min(S.corner.v + pad, (hy2 - hy) / 2) + 'px';
    hit.style.cursor = st.dragging ? 'grabbing' : st.armed ? 'grab' : 'pointer';
    lastFrame = { m, o };
  }

  // ---------- the loop only runs while something moves ----------
  let raf = 0, last = 0;
  function wake() { if (!raf) { last = performance.now(); raf = requestAnimationFrame(tick); } }
  function tick(now) {
    let dt = Math.min(0.05, (now - last) / 1000); last = now;
    S.level.to(st.level, LEVEL);
    S.pulse.to(st.level, PULSE);
    let resting = true;
    while (dt > 0) {
      const h = Math.min(dt, 1 / 240);
      for (const k in S) S[k].step(h);
      dt -= h;
    }
    for (const k in S) if (!S[k].resting) resting = false; else S[k].jump(S[k].t);
    draw(now);
    const moving = !still && (st.open || st.hovering);
    raf = !resting || moving || st.dragging ? requestAnimationFrame(tick) : 0;
  }
  // The panel stays by the caret if the page moves under it.
  addEventListener('scroll', () => { if (atCaret()) wake(); }, { passive: true, capture: true });

  // ---------- fading the window, as NSPanel.alphaValue ----------
  function fade(to, seconds) {
    box.style.transition = seconds ? `opacity ${seconds}s linear` : 'none';
    box.style.opacity = to;
  }

  // ---------- the document: placing the caret, the words yap reads ----------
  const writable = 'p, h1, h2, h3, td, th, dt, dd, figcaption, pre code';
  function caretFromPoint(x, y) {
    if (document.caretPositionFromPoint) {
      const p = document.caretPositionFromPoint(x, y);
      if (!p) return null;
      const r = document.createRange(); r.setStart(p.offsetNode, p.offset); r.collapse(true); return r;
    }
    return document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
  }
  const tape = $('#tape');
  tape.addEventListener('click', (e) => {
    if (e.target.closest('a, button, summary, .caret, kbd, .how, .key-row')) return;
    const sel = getSelection();
    if (sel && !sel.isCollapsed) return;
    const r = caretFromPoint(e.clientX, e.clientY);
    if (!r) return;
    const node = r.startContainer;
    const el = node.nodeType === 1 ? node : node.parentElement;
    const block = el && el.closest(writable);
    if (!block || !tape.contains(block) || el.closest('.note, s.f, .w, .yap')) return;
    if (talking()) return;
    r.insertNode(caret);
    caret.parentNode.normalize && caret.parentNode.normalize();
    restartBlink();
    say('the cursor is in “' + (block.textContent.trim().slice(0, 40) || 'an empty line') + '”.');
  });
  function restartBlink() { caret.style.animation = 'none'; void caret.offsetWidth; caret.style.animation = ''; }

  const columns = [...document.querySelectorAll('.column')];
  function onScreen(el) {
    const r = el.getBoundingClientRect();
    return Math.max(0, Math.min(r.right, innerWidth) - Math.max(r.left, 0)) * Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(r.top, 0));
  }
  // Like the real thing, the words go where your cursor is. If it's scrolled away, it comes to what you're reading.
  function placeCaretForTalk() {
    if (visible(caret)) return;
    const home = caret.closest('.column');
    if (home && onScreen(home) > innerWidth * innerHeight * 0.25) { caret.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' }); if (visible(caret)) return; }
    const ranked = columns.filter((c) => c.querySelector('[data-slot]')).sort((a, b) => onScreen(b) - onScreen(a));
    const col = ranked[0];
    if (!col) return;
    col.querySelector('[data-slot]').appendChild(caret);
    // A jump, not a glide: the panel decides above or below from where the line ends up.
    if (!visible(caret)) caret.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
  }
  const scriptName = () => { const s = caret.closest('[data-script]'); return (s && s.dataset.script) || 'talk'; };

  // The words this page would give the speech model: capitals in the middle, digits, or not in a dictionary.
  const notInDictionary = ['Redis', 'LangWatch', 'rushd', 'wispr', 'parakeet', 'SpeechTranscriber', 'speechtranscriber', 'mlx', 'ghostty'];
  const vocab = new Map();
  (function markWords() {
    const re = /[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9]/g;
    const walker = document.createTreeWalker(tape, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    for (const n of nodes) {
      if (n.parentElement.closest('kbd, .how, h1, .w, s.f, .brand, button, .small, .get')) continue;
      const text = n.nodeValue;
      let m, lastIdx = 0, frag = null;
      re.lastIndex = 0;
      while ((m = re.exec(text))) {
        const w = m[0];
        const odd = /[a-z][A-Z]/.test(w) || (/\d/.test(w) && /[a-z]/i.test(w)) || notInDictionary.some((d) => d.toLowerCase() === w.toLowerCase());
        if (!odd) continue;
        if (!vocab.has(w.toLowerCase()) || /[A-Z]/.test(w)) vocab.set(w.toLowerCase(), w);
        frag = frag || document.createDocumentFragment();
        frag.append(text.slice(lastIdx, m.index));
        const s = document.createElement('span'); s.className = 'ctx'; s.textContent = w; frag.append(s);
        lastIdx = m.index + w.length;
      }
      if (frag) { frag.append(text.slice(lastIdx)); n.replaceWith(frag); }
    }
    // The .w words are on the page too, just held back until their column settles.
    document.querySelectorAll('.w[data-guess]').forEach((w) => { const f = w.dataset.final || w.textContent; vocab.set(f.toLowerCase(), f); });
  })();

  // ---------- the rules: a small version of yap's light cleanup and word fixing ----------
  const swaps = [[/\bbtw\b/gi, 'by the way']];
  const drops = ['basically'];
  const fillers = /^(um+|uh+|erm+|er|uhm|hmm+)$/i;
  function lev(a, b) {
    const d = Array.from({ length: a.length + 1 }, (_, i) => [i]);
    for (let j = 1; j <= b.length; j++) d[0][j] = j;
    for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    return d[a.length][b.length];
  }
  const common = new Set('there their these those where which while would could should about after again being every first never other right still think through under until whole words write wrote reads redid rapid ready rushed'.split(' '));
  function near(word) {
    const w = word.toLowerCase();
    if (vocab.has(w)) return vocab.get(w);
    if (w.length < 5 || common.has(w)) return null;
    const hits = [...new Set(vocab.values())].filter((v) => v.length >= 4 && lev(w, v.toLowerCase()) <= (w.length >= 8 ? 2 : 1));
    return hits.length === 1 ? hits[0] : null;
  }
  function rules(raw) {
    const fixed = [], dropped = [];
    let text = raw;
    const swapped = [];
    for (const [re, to] of swaps) text = text.replace(re, (m) => { swapped.push([m, to]); return to; });
    text = text.replace(/,\s*(like|you know),/gi, (m, w) => { dropped.push(w); return ','; });
    const toks = text.split(/\s+/).filter(Boolean);
    const out = [];
    for (let i = 0; i < toks.length; i++) {
      const t = toks[i], bare = t.replace(/^[^\w]+|[^\w]+$/g, ''), head = t.slice(0, t.indexOf(bare)), tail = t.slice(t.indexOf(bare) + bare.length);
      if (fillers.test(bare) || drops.includes(bare.toLowerCase())) {
        dropped.push(bare);
        if (/[.?!]$/.test(t) && out.length) out[out.length - 1].text = out[out.length - 1].text.replace(/[,]?$/, tail);
        continue;
      }
      const prev = out[out.length - 1];
      if (prev && prev.bare.toLowerCase() === bare.toLowerCase() && !/[,.?!]$/.test(prev.text) && bare.length > 1) { dropped.push(bare); continue; }
      // Two heard words that make one of the page's words, like "lang watch".
      const next = toks[i + 1] && toks[i + 1].replace(/[^\w]+$/g, '');
      if (next && !/[,.?!]$/.test(t)) {
        const joined = vocab.get((bare + next).toLowerCase());
        if (joined) {
          fixed.push([`${bare} ${next}`, joined]);
          out.push({ text: head + joined + toks[i + 1].slice(next.length), bare: joined, fix: `${bare} ${next}` });
          i++; continue;
        }
      }
      const n = bare && near(bare);
      if (n && n !== bare) { fixed.push([bare, n]); out.push({ text: head + n + tail, bare: n, fix: bare }); }
      else out.push({ text: t, bare });
    }
    if (out.length) out[0].text = out[0].text.replace(/^[a-z]/, (c) => (out[0].fix ? c : c.toUpperCase()));
    return { out, fixed: fixed.concat(swapped), dropped };
  }

  // ---------- pasting ----------
  const pastes = [];
  // `plain`: at the caret the text is just there. At the blob it's held in peach a moment, so you see where it went.
  function paste(result, plain) {
    const span = document.createElement('span');
    span.className = plain ? 'pasted settled' : 'pasted';
    result.out.forEach((t) => {
      if (t.fix) { const f = document.createElement('span'); f.className = 'fix'; f.textContent = t.text; f.title = `heard “${t.fix}”`; span.append(f); }
      else span.append(t.text);
      span.append(' ');
    });
    // A leading space when the caret sits right after a word, as ⌘V into the middle of a line would need.
    const at = marker || caret, prev = at.previousSibling;
    const before = prev ? (prev.nodeType === 3 ? prev.nodeValue : prev.textContent) : '';
    if (before && /\S$/.test(before)) span.prepend(' ');
    caret.before(span);
    pastes.push(span);
    if (!plain) setTimeout(() => span.classList.add('settled'), still ? 0 : 900);

    const block = span.closest(writable);
    const old = block && block.nextElementSibling;
    if (old && old.classList.contains('note')) old.remove();
    if (block && (result.fixed.length || result.dropped.length)) {
      const note = document.createElement('p');
      note.className = 'note';
      const parts = [];
      if (result.fixed.length) parts.push(result.fixed.map(([a, b]) => `heard “${a}”, wrote ${b}`).join(', '));
      if (result.dropped.length) parts.push(`dropped “${[...new Set(result.dropped.map((d) => d.toLowerCase()))].join('”, “')}”`);
      note.textContent = parts.join('. ') + '.';
      if (block.matches('td, th, code, h1, h2, h3, dt, dd, figcaption')) {
        const col = block.closest('.column');
        const slot = col && col.querySelector('[data-slot]');
        ((slot && slot.closest('p')) || slot || block).after(note);
      } else block.after(note);
    }
  }
  function undo() {
    const span = pastes.pop();
    if (!span) return;
    const block = span.closest(writable);
    const note = block && block.nextElementSibling;
    span.remove();
    if (note && note.classList.contains('note')) note.remove();
    say('took back the last paste.');
  }

  // ---------- the panel's words ----------
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua) ? ['com.microsoft.edgemac', 'Edge'] : /Firefox\//.test(ua) ? ['org.mozilla.firefox', 'Firefox']
    : /Chrome\//.test(ua) ? ['com.google.Chrome', 'Chrome'] : /Safari\//.test(ua) ? ['com.apple.Safari', 'Safari'] : ['', 'this page'];
  function latest(s, n) {
    if (s.length <= n) return s;
    const tail = s.slice(-Math.max(n, 0)), i = tail.indexOf(' ');
    return '…' + (i >= 0 ? tail.slice(i + 1) : tail);
  }
  // The words, as Said draws them: settled, then guessed (dim, with a band of light), the caret, the hint.
  function saidLine(keep) {
    const p = document.createElement('div');
    // Settled words go through the rules as they come, so a fix shows up underlined while you talk.
    const shown = st.phase === 'done' ? { out: st.result.out } : rules(latest(st.settled, keep - st.guessing.length));
    const a = document.createElement('span'); a.className = 'said';
    shown.out.forEach((t, i) => {
      if (i) a.append(' ');
      if (t.fix) { const f = document.createElement('span'); f.className = 'fix'; f.textContent = t.text; a.append(f); } else a.append(t.text);
    });
    const g = document.createElement('span'); g.className = 'guess';
    g.textContent = (st.guessing && shown.out.length ? ' ' : '') + st.guessing;
    const bar = document.createElement('span'); bar.className = 'bar'; bar.style.opacity = 0.6 + 0.4 * st.level;
    p.append(a, g, bar);
    const trail = st.phase !== 'listening' || atCaret() ? '' : st.locked ? 'click or space to paste' : 'let go to paste';
    if (trail) { const t = document.createElement('span'); t.className = 'trail'; t.textContent = ' —\u00a0' + trail; p.append(t); }
    return p;
  }
  function renderSaid() {
    saidEl.style.display = st.open ? '' : 'none';
    saidEl.innerHTML = '';
    if (atCaret()) {
      // The bubble: the field's size of type, hugging the words until they wrap, three lines at most.
      const b = st.bubble;
      saidEl.style.width = b.textWidest + 'px';
      saidEl.style.fontSize = b.font + 'px';
      saidEl.style.lineHeight = b.line + 'px';
      const p = saidLine(240);
      p.className = 'fit';
      p.style.maxWidth = b.textWidest + 'px';
      saidEl.append(p);
      if (!st.open) return;
      const r = p.getBoundingClientRect(), t = { w: Math.ceil(r.width), h: Math.ceil(p.offsetHeight) };
      const over = t.h > b.shown(t.h) + 0.5;
      saidEl.style.webkitMaskImage = saidEl.style.maskImage = over ? `linear-gradient(transparent, #000 ${Math.min(35, (b.line / b.shown(t.h)) * 100)}%)` : 'none';
      if (Math.abs(t.w - st.text.w) > 0.5 || Math.abs(t.h - st.text.h) > 0.5) { st.text = t; targets(BUBBLE); }
      return;
    }
    saidEl.style.width = panelWidth() - 56 + 'px';
    saidEl.style.fontSize = ''; saidEl.style.lineHeight = '';
    saidEl.style.webkitMaskImage = saidEl.style.maskImage = 'none';
    const count = st.settled.length + st.guessing.length;
    const [size, lines] = count < 140 ? [22, 4] : count < 225 ? [18, 5] : [15, 6];
    const text = document.createElement('div');
    text.style.fontSize = size + 'px';
    text.style.maxHeight = Math.ceil(lines * size * 1.22) + 'px';
    text.style.overflow = 'hidden';
    text.style.display = 'flex'; text.style.flexDirection = 'column'; text.style.justifyContent = 'flex-end';
    text.append(saidLine(330));
    saidEl.append(text);
    // Where it'll paste, so you know before you let go. (Only at the edge: at the caret it's the app you're looking at.)
    if (st.phase === 'listening') { const t = document.createElement('div'); t.className = 'target'; t.textContent = browser[1]; saidEl.append(t); }
    if (!st.open) return;
    const h = saidEl.scrollHeight;
    if (Math.abs(h - st.textHeight) > 0.5) { st.textHeight = h; S.height.to(Math.max(34, h) + 44, TEXT); wake(); }
  }
  function setLevel(v) {
    st.level = v;
    const bar = saidEl.querySelector('.bar');
    if (bar) bar.style.opacity = 0.6 + 0.4 * v;
    wake();
  }

  // ---------- where the words come from: your mic, or a sample I wrote ----------
  const scripts = {
    fn: "Hold fn, talk, let go, and it's pasted wherever your cursor is. On this page the space bar does the job of fn.",
    talk: "This is a sample I wrote, so the page has something to say when you don't use your mic. I'd do the Shanice whistle note, but it only writes down words.",
    bubble: "I'm saying this out loud, and it's landing exactly where my cursor is. No envelope required.",
    settings: "I had a teeth era, then a plum era. Right now I'm in my silver speech bubble era.",
    words: 'So um the reddis cache basically falls over when lang watch is busy, btw.',
    print: "Wispr Flow, we are never ever getting back together. It's not you, it's your RAM.",
    privacy: 'Recordings are off unless you turn them on, so all yap keeps of this is the text, and that goes after thirty days.',
    install: "That's about it. Brew install it, hold fn, and speak now.",
  };
  const outro = "That's all I wrote for this bit. Press use my mic if you want to say your own.";
  const progress = {};

  let source = null;
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  let mic = null;
  const useMic = $('#use-mic'), voiceNote = $('#voice-note');
  const sampleNote = 'without your mic it plays a sample i wrote.';
  if (SR && navigator.mediaDevices && navigator.mediaDevices.getUserMedia) useMic.hidden = false;
  else voiceNote.textContent = "your browser can't do speech recognition, so it plays a sample i wrote.";
  useMic.addEventListener('click', async () => {
    if (mic) {
      mic.stream.getTracks().forEach((t) => t.stop()); mic = null;
      useMic.textContent = 'use my mic'; useMic.setAttribute('aria-pressed', 'false');
      voiceNote.textContent = sampleNote;
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const ac = new (window.AudioContext || window.webkitAudioContext)();
      const analyser = ac.createAnalyser(); analyser.fftSize = 1024;
      ac.createMediaStreamSource(stream).connect(analyser);
      mic = { stream, analyser, buf: new Float32Array(analyser.fftSize), ac };
      useMic.textContent = 'use the sample'; useMic.setAttribute('aria-pressed', 'true');
      voiceNote.textContent = "it's using your mic. your browser is doing the listening, not yap.";
    } catch (_) {
      voiceNote.textContent = "the browser didn't give me the mic, so it'll keep playing the sample.";
    }
  });

  function scriptSource() {
    const name = scriptName();
    const words = (scripts[name] || scripts.talk).split(' ');
    const p = progress[name] || (progress[name] = { i: 0 });
    // Each hold carries on from where the last paste stopped; once it's all said, one line about that, then from the top.
    const list = p.i < words.length ? words : outro.split(' ');
    const from = p.i < words.length ? p.i : 0;
    let n = from, timer = 0, levelTimer = 0;
    const said = () => list.slice(from, n);
    function next() {
      if (n >= list.length) {
        st.guessing = ''; st.settled = said().join(' '); renderSaid();
        levelTimer = setInterval(() => setLevel(Math.random() * 0.08), 140);
        return;
      }
      n++;
      setLevel(0.35 + Math.random() * 0.6);
      const w = said();
      // The last three words are still guesses, as the speech model's are.
      st.guessing = w.slice(Math.max(0, w.length - 3)).join(' ');
      st.settled = w.slice(0, Math.max(0, w.length - 3)).join(' ');
      renderSaid();
      // App.swift's --demo pace: a word every length × 45 + 160 ms.
      timer = setTimeout(next, list[n - 1].length * 45 + 160);
      clearTimeout(levelTimer);
      levelTimer = setTimeout(() => setLevel(0.1 + Math.random() * 0.2), Math.max(80, list[n - 1].length * 30));
    }
    timer = setTimeout(next, 220);
    const halt = () => { clearTimeout(timer); clearTimeout(levelTimer); clearInterval(levelTimer); };
    return {
      stop() {
        halt();
        const text = said().join(' ');
        // The benchmark's 0.9 s wait after you stop.
        return new Promise((res) => setTimeout(() => res(text), still ? 300 : 900));
      },
      commit() { p.i = list === words ? n : n >= list.length ? 0 : p.i; },
      cancel: halt,
    };
  }

  function micSource() {
    const rec = new SR();
    rec.continuous = true; rec.interimResults = true; rec.lang = navigator.language || 'en-GB';
    let finals = '', interim = '', ended = false, failed = false, onEnd = null;
    rec.onresult = (e) => {
      finals = ''; interim = '';
      for (const r of e.results) (r.isFinal ? (finals += r[0].transcript) : (interim += r[0].transcript));
      st.settled = finals.trim(); st.guessing = interim.trim(); renderSaid();
    };
    rec.onerror = (e) => { if (e.error === 'not-allowed' || e.error === 'service-not-allowed') failed = true; };
    rec.onend = () => { ended = true; onEnd && onEnd(); };
    try { rec.start(); } catch (_) { failed = true; }
    let alive = true;
    (function meter() {
      if (!alive || !mic) return;
      mic.analyser.getFloatTimeDomainData(mic.buf);
      let sum = 0; for (const v of mic.buf) sum += v * v;
      setLevel(Math.min(1, Math.sqrt(sum / mic.buf.length) * 7));
      setTimeout(meter, 50);
    })();
    return {
      stop() {
        alive = false;
        return new Promise((res) => {
          const done = () => res((finals + ' ' + interim).trim());
          if (ended) return done();
          onEnd = done;
          try { rec.stop(); } catch (_) { done(); }
          setTimeout(done, 1500);
        }).then((t) => {
          if (failed && !t) voiceNote.textContent = "the browser wouldn't listen (opening the page from disk often does that), so it's back to the sample.";
          if (failed) { mic = null; useMic.textContent = 'use my mic'; useMic.setAttribute('aria-pressed', 'false'); }
          return t;
        });
      },
      commit() {},
      cancel() { alive = false; try { rec.abort(); } catch (_) {} },
    };
  }

  // ---------- the dictation, as in App.swift ----------
  let tapWait = 0, pressedAt = 0, fnDown = false, hideTimer = 0, dripTimer = 0, run = 0;
  const say = (s) => { status.textContent = s; };

  function setPhase(p) {
    st.phase = p;
    clearTimeout(dripTimer);
    st.dripped = false;
    if (!still) S.chipGap.jump(0);
    // Give the chip an attached frame before it stretches away.
    if (p === 'done' && !still) dripTimer = setTimeout(() => { st.dripped = true; targets(PHASE); }, 300);
    const on = p === 'listening' || p === 'finishing';
    document.body.classList.toggle('talking', on);
    fnKey.setAttribute('aria-pressed', String(p === 'listening'));
    targets(PHASE);
    renderSaid();
  }

  // The line the caret is on, as the field lays it out: what the bubble's type and gap are sized from.
  function lineHeight() {
    const block = caret.parentElement, lh = parseFloat(getComputedStyle(block).lineHeight);
    return Number.isFinite(lh) ? lh : anchorRect().height * 1.3;
  }

  // Opens the panel by the caret: out of sight the blob leaves its edge, the glass becomes a dot under the caret,
  // then a frame later it grows into the bubble. Without a caret on screen it opens out of the blob instead.
  function present() {
    const mine = run;
    placeCaretForTalk();
    dropMarker();
    const r = anchorRect();
    if (!r || !r.height) { st.anchor = 'blob'; fade(1, 0); st.open = true; targets(PHASE); renderSaid(); return; }
    fade(0, 0);
    st.anchor = 'caret';
    const b = st.bubble = bubbleFor(lineHeight());
    st.text = { w: 0, h: b.line };
    const roomBelow = innerHeight - 8 - (r.bottom + b.gap), roomAbove = r.top - b.gap - 8;
    st.above = roomBelow < b.tallest && roomAbove > roomBelow;
    st.hovering = false; st.textHeight = 34;
    S.width.jump(b.single); S.height.jump(b.single); S.corner.jump(b.single / 2);
    S.orb.jump(0); S.chip.jump(0); S.ox.jump(0); S.oy.jump(0); S.stretch.jump(1);
    draw(performance.now());
    setTimeout(() => {
      if (mine !== run || st.phase === 'hidden') return;
      fade(1, still ? 0.15 : 0.08);
      st.open = true; targets(PHASE); renderSaid();
    }, still ? 0 : 30);
  }

  // Back to the blob. `faded`: the bubble's already gone, so there's no shrinking into the dot to wait for.
  function backToBlob(faded) {
    const mine = run;
    setTimeout(() => {
      if (mine !== run || st.phase !== 'hidden') return;
      fade(0, faded ? 0 : 0.12);
      setTimeout(() => {
        if (mine !== run || st.phase !== 'hidden') return;
        st.anchor = 'blob'; liftMarker();
        const e = edgeNow();
        S.width.jump(e === 'bottom' ? 44 : 12); S.height.jump(e === 'bottom' ? 12 : 44); S.corner.jump(6);
        S.orb.jump(0); S.chip.jump(0); S.chipGap.jump(0);
        draw(performance.now());
        fade(1, 0.25);
      }, faded ? 20 : 130);
    }, still || faded ? 0 : 380);
  }

  function start() {
    if (st.phase !== 'hidden' || st.dragging) return;
    clearTimeout(hideTimer);
    run++;
    st.hovering = false; st.armed = false; st.locked = false;
    st.settled = ''; st.guessing = ''; st.level = 0; st.textHeight = 34;
    source = mic && SR ? micSource() : scriptSource();
    pressedAt = performance.now();
    st.phase = 'listening';
    present();
    setPhase('listening');
    say(mic ? 'listening.' : 'playing the sample.');
  }

  async function finish() {
    if (st.phase !== 'listening') return;
    const mine = run, src = source;
    st.locked = false; clearTimeout(tapWait); tapWait = 0;
    setLevel(0);
    setPhase('finishing');
    const raw = await src.stop();
    if (mine !== run || st.phase !== 'finishing') return;
    const result = rules(raw);
    if (!result.out.length) return hide();
    src.commit();
    st.result = result;
    st.settled = result.out.map((t) => t.text).join(' '); st.guessing = '';
    renderSaid();
    if (atCaret()) {
      // At the caret the words land right by the bubble, so it gets out of their way: it fades as they're pasted.
      fade(0, 0.12);
      paste(result, true);
      setPhase('done');
      say('pasted: ' + st.settled);
      hideTimer = setTimeout(() => hide(true), 150);
      return;
    }
    paste(result);
    setPhase('done');
    say('pasted: ' + st.settled);
    hideTimer = setTimeout(hide, 900);
  }

  function cancel() {
    if (st.phase !== 'listening' && st.phase !== 'finishing') return;
    clearTimeout(tapWait); tapWait = 0;
    source && source.cancel();
    run++;
    hide();
    say('cancelled. nothing was pasted.');
  }

  function hide(faded) {
    st.locked = false; st.settled = ''; st.guessing = ''; st.level = 0; st.textHeight = 34;
    st.open = false;
    setPhase('hidden');
    if (atCaret()) backToBlob(faded === true);
    else { liftMarker(); fade(1, 0.25); }
  }

  // App.swift's keyDown and keyUp, shared by space, the fn key on the page and nothing else.
  function keyDown() {
    if (st.phase === 'listening') {
      if (tapWait) { clearTimeout(tapWait); tapWait = 0; st.locked = true; renderSaid(); } // second tap: stay open
      else if (st.locked) finish();                                                       // tap again to paste
      return;
    }
    start();
  }
  function keyUp() {
    if (st.phase !== 'listening' || st.locked || tapWait) return;
    if (performance.now() - pressedAt <= 300) {
      // A quick tap is either an accident or the first half of a double tap: wait to see which.
      tapWait = setTimeout(() => { tapWait = 0; cancel(); }, 350);
      return;
    }
    finish();
  }

  // ---------- keys: space stands in for fn ----------
  const isFn = (e) => e.code === 'Space' || e.key === 'Fn';
  // A control you've tabbed to keeps its own space bar.
  const ownsSpace = (t) => t && t.closest && (t.closest('input, textarea, select, [contenteditable]') ||
    (t !== fnKey && t !== hit && t.matches('a:focus-visible, button:focus-visible, summary:focus-visible')));
  addEventListener('keydown', (e) => {
    if (isFn(e)) {
      if (ownsSpace(e.target)) return;
      e.preventDefault();
      if (e.repeat) return;
      fnDown = true;
      keyDown();
      return;
    }
    if (e.key === 'Escape') { if (talking() || st.phase === 'listening') { e.preventDefault(); cancel(); } return; }
    if (e.key === 'Meta') { st.armed = st.hovering || st.armed; if (st.hovering) { hintEl.textContent = 'Drag to move'; wake(); } }
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z' && !talking() && pastes.length) { e.preventDefault(); undo(); return; }
    // fn + another key cancels, so fn+← still works.
    if (fnDown && st.phase === 'listening' && !['Shift', 'Control', 'Alt', 'Meta'].includes(e.key)) { e.stopImmediatePropagation(); e.preventDefault(); cancel(); }
  }, true);
  addEventListener('keyup', (e) => {
    if (e.key === 'Meta') { st.armed = false; hintEl.textContent = 'Click or hold to talk'; wake(); }
    if (!isFn(e) || ownsSpace(e.target)) return;
    e.preventDefault();
    if (!fnDown) return;
    fnDown = false;
    keyUp();
  });
  addEventListener('blur', () => { fnDown = false; if (st.phase === 'listening' && !st.locked) finish(); });

  // ---------- the fn key on the page ----------
  fnKey.setAttribute('aria-pressed', 'false');
  fnKey.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    e.preventDefault();
    fnKey.setPointerCapture(e.pointerId);
    fnDown = true; keyDown();
  });
  const fnUp = () => { if (!fnDown) return; fnDown = false; keyUp(); };
  fnKey.addEventListener('pointerup', fnUp);
  fnKey.addEventListener('pointercancel', fnUp);
  // Enter (or a screen reader's click) starts hands free; again pastes.
  fnKey.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    e.preventDefault();
    if (st.phase === 'hidden') { start(); st.locked = true; renderSaid(); } else if (st.phase === 'listening') finish();
  });
  // A screen reader's activation arrives as a bare click; a click the space bar or Enter made is already handled.
  let keyedAt = -1e9;
  addEventListener('keydown', (e) => { if (isFn(e) || e.key === 'Enter') keyedAt = performance.now(); }, true);
  addEventListener('keyup', (e) => { if (isFn(e) || e.key === 'Enter') keyedAt = performance.now(); }, true);
  fnKey.addEventListener('click', (e) => {
    if (e.detail !== 0 || e.pointerType === 'mouse' || e.pointerType === 'touch' || e.pointerType === 'pen') return;
    if (performance.now() - keyedAt < 500) return;
    if (st.phase === 'hidden') { start(); st.locked = true; renderSaid(); } else if (st.phase === 'listening') finish();
  });

  // ---------- the blob: hover, click, hold, ⌘-drag ----------
  hintEl.textContent = 'Click or hold to talk';
  let holdTimer = 0, heldToStart = false, pressedWhileListening = false, dragFrom = null, prevPt = null;
  const within = (f, x, y, p = 0) => f && x >= f.x - p && x <= f.x + f.w + p && y >= f.y - p && y <= f.y + f.h + p;

  hit.addEventListener('pointerenter', (e) => {
    if (e.pointerType !== 'mouse') return;
    if (st.phase === 'hidden' && !st.dragging && !atCaret()) { st.hovering = true; st.armed = e.metaKey; hintEl.textContent = e.metaKey ? 'Drag to move' : 'Click or hold to talk'; targets(HOVER); }
    controlHovered = true; wake();
  });
  hit.addEventListener('pointermove', (e) => {
    overOrb = talking() && lastFrame && within(lastFrame.o, e.clientX, e.clientY);
    if (st.dragging) return drag(e);
    wake();
  });
  hit.addEventListener('pointerleave', () => {
    if (st.dragging || st.pressed) return;
    controlHovered = false; overOrb = false;
    if (st.hovering) { st.hovering = false; st.armed = false; targets(HOVER); }
    wake();
  });
  hit.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    e.preventDefault();
    hit.setPointerCapture(e.pointerId);
    if (st.armed && st.phase === 'hidden' && !narrow() && !coarse) {
      st.dragging = true; st.hovering = false;
      dragFrom = { x: e.clientX, y: e.clientY, ox: S.ox.v, oy: S.oy.v };
      prevPt = { x: e.clientX, y: e.clientY };
      targets(HOVER); return;
    }
    st.pressed = true; heldToStart = false; pressedWhileListening = st.phase === 'listening';
    clearTimeout(holdTimer);
    if (st.phase === 'hidden') holdTimer = setTimeout(() => { if (st.pressed && st.phase === 'hidden') { heldToStart = true; controlHovered = false; start(); } }, 300);
    wake();
  });
  function drag(e) {
    S.ox.jump(dragFrom.ox + e.clientX - dragFrom.x);
    S.oy.jump(dragFrom.oy + e.clientY - dragFrom.y);
    if (!still) {
      st.pull = { x: e.clientX - prevPt.x, y: e.clientY - prevPt.y };
      if (Math.hypot(st.pull.x, st.pull.y) > 0.5) S.stretch.jump(1 + Math.min(Math.hypot(st.pull.x, st.pull.y) / 90, 0.35));
    }
    prevPt = { x: e.clientX, y: e.clientY };
    wake();
  }
  hit.addEventListener('pointerup', (e) => {
    if (st.dragging) return drop(e);
    if (!st.pressed) return;
    st.pressed = false;
    clearTimeout(holdTimer);
    const inside = lastFrame && (within(lastFrame.m, e.clientX, e.clientY, 4) || within(lastFrame.o, e.clientX, e.clientY));
    if (heldToStart) finish();
    else if (st.phase === 'hidden' && inside) { controlHovered = false; start(); st.locked = true; renderSaid(); }
    else if (pressedWhileListening && st.phase === 'listening' && inside) finish();
    wake();
  });
  hit.addEventListener('pointercancel', () => { st.pressed = false; clearTimeout(holdTimer); if (heldToStart) finish(); });
  hit.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    e.preventDefault();
    if (st.phase === 'hidden') { start(); st.locked = true; renderSaid(); } else if (st.phase === 'listening') finish();
  });

  function drop(e) {
    st.dragging = false; st.armed = false;
    const vw = innerWidth, vh = innerHeight, x = e.clientX, y = e.clientY;
    const d = { left: x, right: vw - x, bottom: vh - y };
    const edge = Object.keys(d).reduce((a, b) => (d[a] <= d[b] ? a : b));
    const before = lastFrame.m;
    st.edge = edge;
    st.slide = edge === 'bottom' ? x - vw / 2 : vh / 2 - y;
    S.ox.jump(0); S.oy.jump(0);
    S.width.jump(edge === 'bottom' ? 44 : 12); S.height.jump(edge === 'bottom' ? 12 : 44); S.corner.jump(6);
    const home = mainFrame();
    S.ox.jump(before.x + before.w / 2 - (home.x + home.w / 2)); S.oy.jump(before.y + before.h / 2 - (home.y + home.h / 2));
    S.ox.to(0, DROP); S.oy.to(0, DROP); S.stretch.to(1, DROP);
    st.hovering = false; controlHovered = false;
    try { localStorage.setItem('yap-spot', JSON.stringify({ edge: st.edge, slide: st.slide })); } catch (_) {}
    wake();
  }

  addEventListener('resize', () => { sizeCanvas(); targets(PHASE); });

  targets(PHASE);
  draw(performance.now());
  // The first time, it shows you where it is the way the app's --demo does: a hover, then back.
  setTimeout(() => {
    if (st.phase !== 'hidden' || controlHovered || atCaret()) return;
    st.hovering = true; targets(HOVER);
    setTimeout(() => { if (!controlHovered && st.phase === 'hidden' && !atCaret()) { st.hovering = false; targets(HOVER); } }, 1800);
  }, 1400);

  // For screenshots: ?demo=listening holds the panel open; ?demo=done lets it paste.
  const demo = new URLSearchParams(location.search).get('demo');
  if (demo) setTimeout(() => { start(); st.locked = true; if (demo === 'done') setTimeout(finish, 2600); }, 300);
})();
