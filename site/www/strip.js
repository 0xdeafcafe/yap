// The strip: moving along the columns, the words on the page settling as you read them, and copying the install lines.
(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const tape = $('#tape');
  const columns = [...document.querySelectorAll('.column')];
  const strip = () => getComputedStyle(tape).display === 'flex';

  // ---------- moving along ----------
  const links = [...document.querySelectorAll('.transport nav a')];
  const prev = $('#previous'), next = $('#next'), bar = $('#progress');
  function current() {
    let best = 0;
    columns.forEach((c, i) => { if (Math.abs(c.offsetLeft - tape.scrollLeft) < Math.abs(columns[best].offsetLeft - tape.scrollLeft)) best = i; });
    return best;
  }
  function go(i) {
    const c = columns[Math.max(0, Math.min(i, columns.length - 1))];
    tape.scrollTo({ left: c.offsetLeft, behavior: reduced.matches ? 'auto' : 'smooth' });
  }
  prev.addEventListener('click', () => go(current() - 1));
  next.addEventListener('click', () => go(current() + 1));
  function position() {
    const max = tape.scrollWidth - tape.clientWidth;
    const f = max > 0 ? tape.scrollLeft / max : 0;
    bar.style.width = f * 100 + '%';
    prev.disabled = tape.scrollLeft < 2;
    next.disabled = tape.scrollLeft >= max - 2;
    let on = links[0];
    for (const a of links) {
      const c = document.querySelector(a.hash);
      if (c && c.offsetLeft <= tape.scrollLeft + 120) on = a;
      a.removeAttribute('aria-current');
    }
    if (f > .99) on = links[links.length - 1];
    on.setAttribute('aria-current', 'location');
  }
  tape.addEventListener('scroll', position, { passive: true });
  addEventListener('resize', position);
  position();

  // In-page links move the strip sideways on wide screens; on phones they're ordinary anchors.
  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[href^="#"]');
    if (!a || !strip()) return;
    const target = document.querySelector(a.getAttribute('href'));
    const col = target && target.closest('.column');
    if (!col) return;
    e.preventDefault();
    tape.scrollTo({ left: col.offsetLeft, behavior: reduced.matches ? 'auto' : 'smooth' });
    history.replaceState(null, '', a.getAttribute('href'));
  });
  // Arrow keys move a column at a time when nothing else wants them.
  addEventListener('keydown', (e) => {
    if (!strip() || e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.target.closest && e.target.closest('input, textarea, select, details, [contenteditable]')) return;
    if (e.key === 'ArrowRight') { e.preventDefault(); go(current() + 1); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); go(current() - 1); }
  });

  // ---------- words settling as their column is read ----------
  // Grey guesses go to ink, "reddis" becomes Redis with yap's peach mark, fillers get struck, then drop out.
  const settle = (col) => {
    col.querySelectorAll('.guess').forEach((g) => g.classList.add('in'));
    col.querySelectorAll('.w.heard').forEach((w, i) => setTimeout(() => {
      w.textContent = w.dataset.final; w.classList.remove('heard'); w.classList.add('fixed');
    }, reduced.matches ? 0 : 500 + i * 200));
    col.querySelectorAll('s.f:not(.struck)').forEach((f, i) => setTimeout(() => {
      f.classList.add('struck');
      if (reduced.matches || f.classList.contains('keep')) return;
      setTimeout(() => { f.style.maxWidth = f.offsetWidth + 'px'; void f.offsetWidth; f.classList.add('gone'); }, 900);
    }, (reduced.matches ? 0 : 600) + i * 250));
  };
  document.querySelectorAll('.w[data-guess]').forEach((w) => {
    w.dataset.final = w.textContent; w.textContent = w.dataset.guess; w.classList.add('heard');
  });
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((es) => {
      for (const e of es) {
        const r = e.intersectionRect;
        // Most of a column on screen, or, for one taller than the screen, half the screen's worth of it.
        if (e.isIntersecting && (e.intersectionRatio >= .5 || (r.height > innerHeight * .5 && r.width > innerWidth * .3))) {
          io.unobserve(e.target); settle(e.target);
        }
      }
    }, { threshold: [0, .1, .2, .3, .4, .5] });
    columns.forEach((c) => io.observe(c));
  } else columns.forEach(settle);

  // ---------- copy ----------
  const copy = $('#copy'), said = $('#copy-status'), commands = $('#commands');
  copy.addEventListener('click', async () => {
    try {
      if (!navigator.clipboard) throw new Error('no clipboard');
      await navigator.clipboard.writeText(commands.textContent);
      said.textContent = 'copied. paste it into a terminal.';
    } catch (_) {
      const r = document.createRange(); r.selectNodeContents(commands);
      const s = getSelection(); s.removeAllRanges(); s.addRange(r);
      said.textContent = 'selected. press ⌘C to copy.';
    }
  });
})();
