// yap, on the edge of a web page. The geometry, springs and timings are ported from
// Sources/Yap/Pill.swift, Teeth.swift and App.swift so the blob moves the way the app's does.
(() => {
  'use strict';

  const $ = (s) => document.querySelector(s);
  const motionQuery = matchMedia('(prefers-reduced-motion: reduce)');
  let still = motionQuery.matches;
  motionQuery.addEventListener('change', (e) => { still = e.matches; wake(); });

  // ---------- springs: SwiftUI's .spring(response:dampingFraction:) ----------
  const PHASE = [0.52, 0.86], HOVER = [0.48, 0.86], LEVEL = [0.28, 0.86], DRIP = [0.65, 0.86],
        TEXT = [0.24, 1], DROP = [0.38, 0.65];

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
    chip: new Spring(0), chipGap: new Spring(0), level: new Spring(0), stretch: new Spring(1),
    ox: new Spring(0), oy: new Spring(0),
  };

  // ---------- state, as in Dictation ----------
  const st = {
    phase: 'hidden', // hidden, listening, finishing, done
    hovering: false, armed: false, dragging: false, pressed: false, locked: false,
    settled: '', guessing: '', level: 0, dripped: false,
    edge: 'right', slide: 0, pull: { x: 0, y: 0 }, textHeight: 34,
  };

  const coarse = matchMedia('(pointer: coarse)').matches;
  try {
    const saved = JSON.parse(localStorage.getItem('yap-spot') || 'null');
    if (saved && ['right', 'left', 'bottom'].includes(saved.edge)) { st.edge = saved.edge; st.slide = saved.slide || 0; }
  } catch (_) {}
  const narrow = () => innerWidth < 700;
  const edgeNow = () => (narrow() || coarse ? 'bottom' : st.edge);

  const talking = () => st.phase === 'listening' || st.phase === 'finishing';
  const expanded = () => st.phase !== 'hidden';
  const panelWidth = () => {
    const e = edgeNow();
    const room = e === 'bottom' ? innerWidth - 20 : innerWidth - 20 - 38 - 16;
    return Math.max(220, Math.min(496, room));
  };

  function targets(cause) {
    const e = edgeNow(), ex = expanded();
    S.width.to(ex ? panelWidth() : st.hovering ? 184 : e === 'bottom' ? 44 : 12, cause);
    S.height.to(ex ? Math.max(34, st.textHeight) + 44 : st.hovering ? 40 : e === 'bottom' ? 12 : 44, cause);
    S.corner.to(ex ? 26 : st.hovering ? 20 : 6, cause);
    S.orb.to(talking() ? 1 : 0, cause);
    S.chip.to(st.phase === 'done' ? 1 : 0, cause);
    S.chipGap.to(still || st.dripped ? 24 : 0, DRIP);
    wake();
  }

  // ---------- geometry: LiquidOutline in viewport points ----------
  const K = 0.5523;
  function mainFrame() {
    const e = edgeNow(), w = Math.max(1, S.width.v), h = Math.max(1, S.height.v), vw = innerWidth, vh = innerHeight;
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
  function orbFrame(m) {
    const e = edgeNow(), d = 38 * Math.max(0, S.orb.v), gap = orbGap();
    if (e === 'bottom') return { x: m.x + m.w / 2 - d / 2, y: m.y - gap - d, w: d, h: d };
    return { x: e === 'right' ? m.x - gap - d : m.x + m.w + gap, y: m.y + m.h / 2 - d / 2, w: d, h: d };
  }
  const orbGap = () => (still ? 4 : 1 + 10 * Math.min(Math.max(S.level.v, 0), 1));
  function chipFrame(m) {
    const a = Math.max(0, S.chip.v);
    return { x: m.x + m.w / 2 - 49 * a, y: m.y + m.h + Math.max(0, S.chipGap.v), w: 98 * a, h: 30 * a };
  }

  // A subpath is a start point and segments; every one is made clockwise so overlaps union under nonzero.
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

  function mapSub(p, fn) {
    return { start: fn(p.start), segs: p.segs.map((s) => [s[0], ...s.slice(1).map(fn)]) };
  }
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
    const m = mainFrame(), e = edgeNow();
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
        const x = ch.x + ch.w / 2, top = m.y + m.h - 0.5, bottom = ch.y + 0.5;
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
  const glass = $('#yap-glass'), canvas = $('#yap-edge'), ctx = canvas.getContext('2d');
  const saidEl = $('#yap-said'), hintEl = $('#yap-hint'), orbEl = $('#yap-orb'), chipEl = $('#yap-chip');
  const jaw = $('#jaw'), hit = $('#yap-hit');
  let dpr = 1;
  function sizeCanvas() {
    dpr = Math.min(2, devicePixelRatio || 1);
    canvas.width = innerWidth * dpr; canvas.height = innerHeight * dpr;
  }
  sizeCanvas();

  function draw(now) {
    const { subs, m, o, ch } = outline();
    const xs = subs.flatMap((p) => [p.start[0], ...p.segs.flatMap((s) => s.slice(1).map((q) => q[0]))]);
    const ys = subs.flatMap((p) => [p.start[1], ...p.segs.flatMap((s) => s.slice(1).map((q) => q[1]))]);
    const bx = Math.floor(Math.min(...xs)) - 2, by = Math.floor(Math.min(...ys)) - 2;
    const bw = Math.ceil(Math.max(...xs)) + 2 - bx, bh = Math.ceil(Math.max(...ys)) + 2 - by;
    glass.style.transform = `translate(${bx}px, ${by}px)`;
    glass.style.width = bw + 'px'; glass.style.height = bh + 'px';
    glass.style.clipPath = `path('${toD(subs, bx, by)}')`;

    // Contents, positioned in the glass's own box. The clip-path masks them like .mask(shape).
    const ex = expanded();
    saidEl.style.left = m.x - bx + 28 + 'px';
    saidEl.style.top = m.y - by + (m.h - st.textHeight) / 2 + 'px';
    hintEl.style.display = !ex && st.hovering ? '' : 'none';
    hintEl.style.left = m.x - bx + 'px'; hintEl.style.width = m.w + 'px';
    hintEl.style.top = m.y - by + m.h / 2 - 7.5 + 'px';
    hintEl.style.opacity = Math.max(0, Math.min(1, (S.width.v - 60) / 100));
    orbEl.style.left = o.x - bx + o.w / 2 - 19 + 'px'; orbEl.style.top = o.y - by + o.h / 2 - 19 + 'px';
    orbEl.style.opacity = Math.min(1, Math.max(0, S.orb.v));
    orbEl.style.background = st.pressed && talking() ? 'rgba(255,255,255,.25)' : overOrb ? 'rgba(255,255,255,.18)' : 'transparent';
    chipEl.style.left = ch.x - bx + ch.w / 2 - 49 + 'px'; chipEl.style.width = '98px';
    chipEl.style.top = ch.y - by + ch.h / 2 - 15 + 'px'; chipEl.style.height = '30px';
    chipEl.style.opacity = Math.min(1, Math.max(0, S.chip.v));
    const open = still ? 0.5 : Math.min(Math.max(S.level.v, 0), 1);
    jaw.setAttribute('transform', `rotate(${8 + 26 * open} 27 21.5)`);
    const press = st.pressed && !talking() ? 0.22 : controlHovered ? 0.13 : 0;
    glass.style.boxShadow = press ? `inset 0 0 0 999px rgba(255,255,255,${press})` : 'none';

    // The edge: one hairline round the union, plus the light that travels round it while it's open.
    const W = canvas.width, H = canvas.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, W, H);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const path = new Path2D(toD(subs));
    ctx.globalCompositeOperation = 'source-over';
    ctx.lineWidth = 1.6;
    ctx.strokeStyle = `rgba(255,255,255,${controlHovered ? 0.65 : 0.3})`;
    ctx.stroke(path);
    const moving = !still && (ex || st.hovering);
    const angle = (moving ? ((now / 1000) % 6) * 60 : 225) * Math.PI / 180;
    if (ctx.createConicGradient) {
      const g = ctx.createConicGradient(angle, m.x + m.w / 2, m.y + m.h / 2);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.4, 'rgba(255,255,255,0)');
      g.addColorStop(0.48, 'rgba(255,255,255,.9)'); g.addColorStop(0.51, 'rgba(255,255,255,.45)');
      g.addColorStop(0.59, 'rgba(255,255,255,0)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.lineWidth = 2.4; ctx.strokeStyle = g; ctx.stroke(path);
    }
    // Keep only the outside half of the strokes, so the inner seams of the union never show.
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fill(path);
    ctx.globalCompositeOperation = 'source-over';

    // The button that takes the pointer and keyboard focus sits on the blob's body.
    const pad = 4;
    const hx = Math.min(m.x, talking() ? o.x : m.x) - pad, hy = Math.min(m.y, talking() ? o.y : m.y) - pad;
    const hx2 = Math.max(m.x + m.w, talking() ? o.x + o.w : 0) + pad, hy2 = Math.max(m.y + m.h, talking() ? o.y + o.h : 0) + pad;
    const live = st.phase === 'hidden' || st.phase === 'listening';
    hit.style.display = live ? '' : 'none';
    hit.style.transform = `translate(${hx}px, ${hy}px)`;
    hit.style.width = hx2 - hx + 'px'; hit.style.height = hy2 - hy + 'px';
    hit.style.borderRadius = Math.min(S.corner.v + pad, (hy2 - hy) / 2) + 'px';
    hit.style.cursor = st.dragging ? 'grabbing' : st.armed ? 'grab' : 'pointer';
    lastFrame = { m, o };
  }
  let lastFrame = null, controlHovered = false, overOrb = false;

  // ---------- the loop only runs while something moves ----------
  let raf = 0, last = 0;
  function wake() { if (!raf) { last = performance.now(); raf = requestAnimationFrame(tick); } }
  function tick(now) {
    let dt = Math.min(0.05, (now - last) / 1000); last = now;
    S.level.to(st.level, LEVEL);
    let resting = true;
    while (dt > 0) {
      const h = Math.min(dt, 1 / 240);
      for (const k in S) S[k].step(h);
      dt -= h;
    }
    for (const k in S) if (!S[k].resting) resting = false; else S[k].jump(S[k].t);
    draw(now);
    const moving = !still && (expanded() || st.hovering);
    raf = !resting || moving || st.dragging ? requestAnimationFrame(tick) : 0;
  }

  // ---------- the document: caret, pasting, the words yap reads ----------
  const doc = $('#doc');
  const caret = document.createElement('span');
  caret.className = 'caret'; caret.setAttribute('aria-hidden', 'true');
  const heroSlot = $('.hero [data-slot]');
  heroSlot.appendChild(caret);
  let caretByClick = false;

  const writable = 'p, h1, h2, td, th, figcaption, pre code';
  function caretFromPoint(x, y) {
    if (document.caretPositionFromPoint) {
      const p = document.caretPositionFromPoint(x, y);
      if (!p) return null;
      const r = document.createRange(); r.setStart(p.offsetNode, p.offset); r.collapse(true); return r;
    }
    return document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
  }
  doc.addEventListener('click', (e) => {
    if (e.target.closest('a, button, .caret')) return;
    const sel = getSelection();
    if (sel && !sel.isCollapsed) return;
    const r = caretFromPoint(e.clientX, e.clientY);
    if (!r) return;
    let node = r.startContainer;
    const el = node.nodeType === 1 ? node : node.parentElement;
    const block = el && el.closest(writable);
    if (!block || !doc.contains(block) || el.closest('.how, .note, kbd')) return;
    if (node.nodeType === 3 && node.parentElement === caret) return;
    r.insertNode(caret);
    caretByClick = true;
    restartBlink();
  });
  function restartBlink() { caret.style.animation = 'none'; void caret.offsetWidth; caret.style.animation = ''; }

  function inView(el) { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; }
  function sectionInView() {
    const mid = innerHeight * 0.45;
    let best = null, dist = Infinity;
    for (const s of doc.querySelectorAll('section')) {
      const r = s.getBoundingClientRect();
      const d = r.top <= mid && r.bottom >= mid ? 0 : Math.min(Math.abs(r.top - mid), Math.abs(r.bottom - mid));
      if (d < dist) { dist = d; best = s; }
    }
    return best;
  }
  // Like the real thing, the words go where your cursor is. If it's scrolled away, it comes to the section you're reading.
  function placeCaretForTalk() {
    if (inView(caret)) return;
    const s = sectionInView();
    const slot = s && s.querySelector('[data-slot]');
    if (slot) { slot.appendChild(caret); caretByClick = false; }
  }
  const scriptName = () => (caret.closest('section') || {}).dataset?.script || 'hero';

  // The words this page would give the speech model: capitals in the middle, digits, or not in a dictionary.
  const notInDictionary = ['Redis', 'LangWatch', 'rushd', 'wispr', 'parakeet', 'speechtranscriber', 'mlx', 'ghostty'];
  const vocab = new Map();
  (function markWords() {
    const re = /[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9]/g;
    const walker = document.createTreeWalker(doc, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    for (const n of nodes) {
      if (n.parentElement.closest('kbd, .how, h1, .sock')) continue;
      const text = n.nodeValue;
      let m, lastIdx = 0, frag = null;
      re.lastIndex = 0;
      while ((m = re.exec(text))) {
        const w = m[0];
        const odd = /[a-z][A-Z]/.test(w) || (/\d/.test(w) && /[a-z]/i.test(w)) ||
          notInDictionary.some((d) => d.toLowerCase() === w.toLowerCase());
        if (!odd) continue;
        if (!vocab.has(w.toLowerCase()) || /[A-Z]/.test(w)) vocab.set(w.toLowerCase(), w);
        frag = frag || document.createDocumentFragment();
        frag.append(text.slice(lastIdx, m.index));
        const s = document.createElement('span'); s.className = 'ctx'; s.textContent = w; frag.append(s);
        lastIdx = m.index + w.length;
      }
      if (frag) { frag.append(text.slice(lastIdx)); n.replaceWith(frag); }
    }
  })();

  // ---------- the rules, a small version of yap's light cleanup and word fixing ----------
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
  const common = new Set('there their these those where which while would could should about after again being every first never other right still think through under until whole words write wrote reads redid rapid ready'.split(' '));
  function near(word) {
    const w = word.toLowerCase();
    if (vocab.has(w)) return vocab.get(w);
    if (w.length < 5 || common.has(w)) return null;
    const hits = [...vocab.values()].filter((v) => v.length >= 4 && lev(w, v.toLowerCase()) <= (w.length >= 8 ? 2 : 1));
    return hits.length === 1 ? hits[0] : null;
  }
  function rules(raw) {
    const fixed = [], dropped = [];
    let text = raw;
    for (const [re, to] of swaps) text = text.replace(re, (m) => { fixed.push([m, to]); return to; });
    text = text.replace(/,\s*(like|you know),/gi, (m, w) => { dropped.push(w); return ','; });
    let toks = text.split(/\s+/).filter(Boolean);
    const out = [];
    for (let i = 0; i < toks.length; i++) {
      const t = toks[i], bare = t.replace(/^[^\w]+|[^\w]+$/g, ''), tail = t.slice(t.indexOf(bare) + bare.length), head = t.slice(0, t.indexOf(bare));
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
          const nt = toks[i + 1];
          fixed.push([`${bare} ${next}`, joined]);
          out.push({ text: head + joined + nt.slice(next.length), bare: joined, fix: `${bare} ${next}` });
          i++; continue;
        }
      }
      const n = bare && near(bare);
      if (n && n !== bare) {
        fixed.push([bare, n]);
        out.push({ text: head + n + tail, bare: n, fix: bare });
      } else out.push({ text: t, bare });
    }
    if (out.length) out[0].text = out[0].text.replace(/^[a-z]/, (c) => (out[0].fix ? c : c.toUpperCase()));
    return { out, fixed, dropped };
  }

  // ---------- pasting ----------
  const pastes = [];
  function paste(result) {
    const span = document.createElement('span');
    span.className = 'pasted';
    for (const [i, t] of result.out.entries()) {
      if (t.fix) {
        const mk = document.createElement('mark');
        mk.textContent = t.text; mk.title = `heard "${t.fix}"`;
        span.append(mk);
      } else span.append(t.text);
      span.append(i < result.out.length - 1 ? ' ' : ' ');
    }
    // A leading space when the caret sits right after a word, as ⌘V into the middle of a line would need.
    const prev = caret.previousSibling;
    const before = prev && prev.nodeType === 3 ? prev.nodeValue : prev ? prev.textContent : '';
    if (before && /\S$/.test(before)) span.prepend(' ');
    caret.before(span);
    pastes.push(span);
    setTimeout(() => span.classList.add('settled'), 900);

    const block = span.closest(writable);
    const old = block.nextElementSibling;
    if (old && old.classList.contains('note')) old.remove();
    if (result.fixed.length || result.dropped.length) {
      const note = document.createElement('p');
      note.className = 'note';
      const parts = [];
      if (result.fixed.length) parts.push(result.fixed.map(([a, b]) => `heard "${a}", wrote ${b}`).join(', '));
      if (result.dropped.length) parts.push(`dropped "${[...new Set(result.dropped.map((d) => d.toLowerCase()))].join('", "')}"`);
      note.textContent = parts.join('. ') + '.';
      if (block.matches('td, th, code, h1, h2, figcaption')) {
        (block.closest('section') || doc).querySelector('[data-slot]')?.before(note);
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
  }

  // ---------- the panel's words ----------
  function latest(s, n) {
    if (s.length <= n) return s;
    const tail = s.slice(-Math.max(n, 0)), i = tail.indexOf(' ');
    return '…' + (i >= 0 ? tail.slice(i + 1) : tail);
  }
  function renderSaid() {
    saidEl.style.display = expanded() ? '' : 'none';
    saidEl.style.width = panelWidth() - 56 + 'px';
    const count = st.settled.length + st.guessing.length;
    const [size, lines] = count < 140 ? [22, 4] : count < 225 ? [18, 5] : [15, 6];
    saidEl.style.fontSize = size + 'px';
    saidEl.style.maxHeight = Math.ceil(lines * size * 1.22) + 'px';
    const settled = latest(st.settled, 330 - st.guessing.length);
    const gap = !st.guessing || !settled || settled.endsWith(' ') ? '' : ' ';
    const trail = st.phase !== 'listening' ? '' : st.locked ? 'click or space to paste' : 'let go to paste';
    saidEl.innerHTML = '';
    const p = document.createElement('div');
    const a = document.createElement('span'); a.className = 'said'; a.textContent = settled;
    const g = document.createElement('span'); g.className = 'guess'; g.textContent = gap + st.guessing;
    const bar = document.createElement('span'); bar.className = 'bar'; bar.style.opacity = 0.6 + 0.4 * st.level;
    p.append(a, g, bar);
    if (trail) { const t = document.createElement('span'); t.className = 'trail'; t.textContent = ' — ' + trail; p.append(t); }
    saidEl.append(p);
    if (!expanded()) return publish();
    const h = Math.min(saidEl.scrollHeight, parseFloat(saidEl.style.maxHeight));
    if (Math.abs(h - st.textHeight) > 0.5) { st.textHeight = h; S.height.to(Math.max(34, h) + 44, TEXT); wake(); }
    publish();
  }
  function setLevel(v) {
    st.level = v;
    const bar = saidEl.querySelector('.bar');
    if (bar) bar.style.opacity = 0.6 + 0.4 * v;
    wake();
  }

  // ---------- live.sock, as this page would see it ----------
  const ua = navigator.userAgent;
  const app = /Edg\//.test(ua) ? 'com.microsoft.edgemac' : /Firefox\//.test(ua) ? 'org.mozilla.firefox'
    : /Chrome\//.test(ua) ? 'com.google.Chrome' : /Safari\//.test(ua) ? 'com.apple.Safari' : '';
  const sockOut = $('#sock-out');
  const sockLines = [];
  let lastLine = '';
  function publish(force) {
    const line = JSON.stringify({ app, guessing: st.guessing, level: Math.round(st.level * 100), locked: st.locked,
      phase: st.phase, settled: st.settled });
    if (line === lastLine && !force) return;
    lastLine = line;
    sockLines.push(line);
    while (sockLines.length > 4) sockLines.shift();
    sockOut.innerHTML = '';
    sockLines.forEach((l, i) => {
      const s = document.createElement('span');
      if (i < sockLines.length - 1) s.className = 'old';
      s.textContent = l + '\n';
      sockOut.append(s);
    });
  }
  $('#ctx-line').textContent = JSON.stringify({ context: { app, words: [...vocab.values()].slice(0, 200) } });
  publish(true);

  // ---------- where the words come from: your mic, or a dictation of mine ----------
  const scripts = {
    hero: "Hi, it's Alex. I'm not really here, this is a dictation I did earlier so the page has something to paste when you don't use your mic. It goes wherever your cursor is, which on this page is wherever you last clicked.",
    blob: "The blob sits on the right edge until you need it. If you'd rather have it on the bottom of the screen, it opens upwards from there, and if you hold command you can drag it to whichever edge you like.",
    tiny: "Right now it isn't doing anything, and that's the point. It only wakes up while you're holding the key down.",
    words: "So um the reddis cache basically falls over when lang watch is busy, btw.",
    privacy: "Recordings are off unless you turn them on, so all yap kept of this was the text, and that goes after thirty days.",
    bench: "It isn't the most accurate one I tried. Parakeet and Wispr Flow both got a few more words right, but it's close, and it doesn't cost anything to keep running.",
    live: "While I'm talking, this is what yap writes to the socket, a line every time it changes its mind about what I said.",
    end: "That's about it. Brew install it, hold fn, and say something.",
  };
  const outro = "That's all I recorded for this bit. Press use my mic if you want to say your own.";
  const progress = {};

  let source = null;
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  let mic = null; // { stream, analyser, buf }
  const useMic = $('#use-mic'), voiceNote = $('#voice-note');
  if (SR && navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    useMic.hidden = false;
  } else {
    voiceNote.textContent = "your browser can't do speech recognition, so it plays one of my dictations.";
  }
  useMic.addEventListener('click', async () => {
    if (mic) {
      mic.stream.getTracks().forEach((t) => t.stop()); mic = null;
      useMic.textContent = 'use my mic';
      voiceNote.textContent = "if you don't use your mic, it plays one of my dictations instead.";
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const ac = new (window.AudioContext || window.webkitAudioContext)();
      const analyser = ac.createAnalyser(); analyser.fftSize = 1024;
      ac.createMediaStreamSource(stream).connect(analyser);
      mic = { stream, analyser, buf: new Float32Array(analyser.fftSize), ac };
      useMic.textContent = 'play your dictation instead';
      voiceNote.textContent = "it's using your mic now. your browser is doing the listening, not yap.";
    } catch (_) {
      voiceNote.textContent = "the browser didn't give me the mic, so it'll keep playing my dictation.";
    }
  });

  function scriptSource() {
    const name = scriptName();
    const words = (scripts[name] || scripts.hero).split(' ');
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
      const words = said();
      st.guessing = words.slice(Math.max(0, words.length - 3)).join(' ');
      st.settled = words.slice(0, Math.max(0, words.length - 3)).join(' ');
      renderSaid();
      timer = setTimeout(next, list[n - 1].length * 45 + 160);
      // a breath between words, so the teeth chatter instead of holding open
      clearTimeout(levelTimer);
      levelTimer = setTimeout(() => setLevel(0.1 + Math.random() * 0.2), Math.max(80, list[n - 1].length * 30));
    }
    timer = setTimeout(next, 220);
    return {
      stop() {
        clearTimeout(timer); clearTimeout(levelTimer); clearInterval(levelTimer);
        const text = said().join(' ');
        return new Promise((res) => setTimeout(() => res(text), still ? 300 : 900));
      },
      commit() { p.i = list === words ? n : n >= list.length ? 0 : p.i; },
      cancel() { clearTimeout(timer); clearTimeout(levelTimer); clearInterval(levelTimer); },
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
        }).then((t) => { if (failed && !t) voiceNote.textContent = "the browser wouldn't listen, so it's back to my dictation."; if (failed) mic = null; return t; });
      },
      commit() {},
      cancel() { alive = false; try { rec.abort(); } catch (_) {} },
    };
  }

  // ---------- the dictation, as in App.swift ----------
  let tapWait = 0, pressedAt = 0, spaceDown = false, hideTimer = 0, dripTimer = 0, run = 0;

  function setPhase(p) {
    st.phase = p;
    clearTimeout(dripTimer);
    st.dripped = false;
    if (!still) S.chipGap.jump(0);
    if (p === 'done' && !still) dripTimer = setTimeout(() => { st.dripped = true; targets(PHASE); }, 300);
    document.body.classList.toggle('talking', p === 'listening' || p === 'finishing');
    targets(PHASE);
    renderSaid();
  }

  function start() {
    if (st.phase !== 'hidden' || st.dragging) return;
    clearTimeout(hideTimer);
    placeCaretForTalk();
    st.hovering = false; st.armed = false; st.locked = false;
    st.settled = ''; st.guessing = ''; st.level = 0;
    st.textHeight = 34;
    source = mic && SR ? micSource() : scriptSource();
    pressedAt = performance.now();
    run++;
    setPhase('listening');
  }

  async function finish() {
    if (st.phase !== 'listening') return;
    const mine = run, src = source;
    st.locked = false; clearTimeout(tapWait); tapWait = 0;
    st.level = 0; setLevel(0);
    setPhase('finishing');
    const raw = await src.stop();
    if (mine !== run || st.phase !== 'finishing') return;
    const result = rules(raw);
    if (!result.out.length) return hide();
    src.commit();
    st.settled = result.out.map((t) => t.text).join(' '); st.guessing = '';
    setPhase('done');
    paste(result);
    hideTimer = setTimeout(hide, 900);
  }

  function cancel() {
    if (st.phase !== 'listening' && st.phase !== 'finishing') return;
    run++;
    clearTimeout(tapWait); tapWait = 0;
    source && source.cancel();
    hide();
  }

  function hide() {
    st.locked = false; st.settled = ''; st.guessing = ''; st.level = 0;
    st.textHeight = 34;
    setPhase('hidden');
  }

  // ---------- keys: space stands in for fn ----------
  const isFn = (e) => e.code === 'Space' || e.key === 'Fn';
  addEventListener('keydown', (e) => {
    if (isFn(e)) {
      if (e.target.closest && e.target.closest('input, textarea, select, [contenteditable]')) return;
      e.preventDefault();
      if (e.repeat) return;
      spaceDown = true;
      if (st.phase === 'listening') {
        if (tapWait) { clearTimeout(tapWait); tapWait = 0; st.locked = true; renderSaid(); } // second tap: stay open
        else if (st.locked) finish();                                                       // tap again to paste
        return;
      }
      start();
      return;
    }
    if (e.key === 'Escape') { if (talking()) { e.preventDefault(); cancel(); } return; }
    if (e.key === 'Meta') { st.armed = st.hovering || st.armed; if (st.hovering) { hintEl.textContent = 'Drag to move'; wake(); } }
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z' && !talking() && pastes.length) { e.preventDefault(); undo(); return; }
    // fn + another key cancels, so fn+← still works.
    if (spaceDown && st.phase === 'listening' && !['Shift', 'Control', 'Alt', 'Meta'].includes(e.key)) cancel();
  });
  addEventListener('keyup', (e) => {
    if (e.key === 'Meta') { st.armed = false; hintEl.textContent = 'Click or hold to talk'; wake(); }
    if (!isFn(e)) return;
    e.preventDefault();
    spaceDown = false;
    if (st.phase !== 'listening' || st.locked || tapWait) return;
    if (performance.now() - pressedAt <= 300) {
      // A quick tap is either an accident or the first half of a double tap: wait to see which.
      tapWait = setTimeout(() => { tapWait = 0; cancel(); }, 350);
      return;
    }
    finish();
  });
  addEventListener('blur', () => { spaceDown = false; if (st.phase === 'listening' && !st.locked) finish(); });

  // ---------- the pointer: hover, click, hold, ⌘-drag ----------
  hintEl.textContent = 'Click or hold to talk';
  let holdTimer = 0, heldToStart = false, pressedWhileListening = false, dragFrom = null, prevPt = null;
  const within = (f, x, y, p = 0) => f && x >= f.x - p && x <= f.x + f.w + p && y >= f.y - p && y <= f.y + f.h + p;

  hit.addEventListener('pointerenter', (e) => {
    if (e.pointerType !== 'mouse') return;
    if (st.phase === 'hidden' && !st.dragging) { st.hovering = true; st.armed = e.metaKey; hintEl.textContent = e.metaKey ? 'Drag to move' : 'Click or hold to talk'; targets(HOVER); }
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
    if (st.phase === 'hidden') holdTimer = setTimeout(() => { if (st.pressed && st.phase === 'hidden') { heldToStart = true; start(); } }, 300);
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
    else if (st.phase === 'hidden' && inside) { start(); st.locked = true; renderSaid(); }
    else if (pressedWhileListening && st.phase === 'listening' && inside) finish();
    wake();
  });
  hit.addEventListener('pointercancel', () => { st.pressed = false; clearTimeout(holdTimer); if (heldToStart) finish(); });
  // Keyboard users: Enter on the blob starts hands free, Enter again pastes.
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
    // Where it is on screen now, so the snap starts from there.
    const before = lastFrame.m;
    st.edge = edge;
    st.slide = edge === 'bottom' ? x - vw / 2 : vh / 2 - y;
    S.ox.jump(0); S.oy.jump(0);
    // Back to the resting size first, then measure the new home and spring from where it was.
    S.width.jump(edge === 'bottom' ? 44 : 12); S.height.jump(edge === 'bottom' ? 12 : 44); S.corner.jump(6);
    const home = mainFrame();
    S.ox.jump(before.x + before.w / 2 - (home.x + home.w / 2)); S.oy.jump(before.y + before.h / 2 - (home.y + home.h / 2));
    S.ox.to(0, DROP); S.oy.to(0, DROP); S.stretch.to(1, DROP);
    st.hovering = false; controlHovered = false;
    try { localStorage.setItem('yap-spot', JSON.stringify({ edge: st.edge, slide: st.slide })); } catch (_) {}
    wake();
  }

  // ---------- small things ----------
  addEventListener('resize', () => { sizeCanvas(); targets(PHASE); });
  document.querySelectorAll('[data-copy]').forEach((b) => b.addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(b.dataset.copy); b.textContent = 'copied'; }
    catch (_) { b.textContent = 'select and copy them'; }
    setTimeout(() => (b.textContent = 'copy both lines'), 1600);
  }));

  // The first time, it shows you where it is the way the app's --demo does: a hover, then back.
  targets(PHASE);
  draw(performance.now());
  setTimeout(() => {
    if (st.phase !== 'hidden' || controlHovered) return;
    st.hovering = true; targets(HOVER);
    setTimeout(() => { if (!controlHovered && st.phase === 'hidden') { st.hovering = false; targets(HOVER); } }, 1800);
  }, 1400);

  // For the screenshots: ?demo=listening or ?demo=done holds the panel open.
  const demo = new URLSearchParams(location.search).get('demo');
  if (demo) {
    setTimeout(() => {
      start();
      if (demo === 'done') setTimeout(() => finish(), 2600);
    }, 300);
  }
})();
