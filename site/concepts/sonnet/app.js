(() => {
  const root = document.documentElement;
  root.classList.add('js');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // paragraphs start as the grey tail of a dictation and settle once they're in the upper part of the screen
  const settleSay = new IntersectionObserver((es) => {
    for (const e of es) if (e.isIntersecting) { e.target.classList.add('in'); settleSay.unobserve(e.target); }
  }, { rootMargin: '0px 0px -12% 0px' });
  document.querySelectorAll('.say').forEach((el) => settleSay.observe(el));

  // guessed words: show what the model heard, then the corrected word
  const guessed = document.querySelectorAll('.w[data-guess]');
  const settleWord = new IntersectionObserver((es) => {
    for (const e of es) {
      if (!e.isIntersecting) continue;
      const el = e.target;
      settleWord.unobserve(el);
      setTimeout(() => {
        el.textContent = el.dataset.final;
        el.classList.remove('guess');
        if (!reduce) el.classList.add('firm');
      }, el.closest('.hero h1') ? 900 : 500);
    }
  }, { rootMargin: '0px 0px -35% 0px' });
  guessed.forEach((el) => {
    el.dataset.final = el.textContent;
    el.textContent = el.dataset.guess;
    el.classList.add('guess');
    settleWord.observe(el);
  });

  // fillers: struck when they come into view, then they drop out of the line
  const fillers = new IntersectionObserver((es) => {
    for (const e of es) {
      if (!e.isIntersecting) continue;
      const el = e.target;
      fillers.unobserve(el);
      setTimeout(() => {
        el.classList.add('struck');
        if (reduce) return;
        setTimeout(() => {
          el.style.maxWidth = el.offsetWidth + 'px';
          void el.offsetWidth;
          el.classList.add('gone');
        }, 900);
      }, 400);
    }
  }, { rootMargin: '0px 0px -30% 0px' });
  document.querySelectorAll('s.f').forEach((el) => fillers.observe(el));

  // the pinned teeth: the jaw opens with how fast you scroll, the way it opens with how loud you are
  const jaw = document.getElementById('jaw');
  const panel = document.getElementById('panel');
  const label = document.getElementById('panel-text');
  const paste = document.getElementById('paste');
  let last = scrollY, open = 14, pasted = false;
  const tick = () => {
    const v = Math.abs(scrollY - last);
    last = scrollY;
    const target = pasted ? 0 : Math.min(26, 7 + v * 0.9);
    open += (target - open) * 0.25;
    jaw.style.transform = `rotate(${open.toFixed(1)}deg)`;
    requestAnimationFrame(tick);
  };
  if (!reduce) requestAnimationFrame(tick);
  else jaw.style.transform = 'rotate(14deg)';

  // at the bottom it pastes
  const atEnd = new IntersectionObserver((es) => {
    const on = es[0].isIntersecting;
    if (on === pasted) return;
    pasted = on;
    panel.classList.toggle('pasted', on);
    label.innerHTML = on
      ? '<svg width="13" height="13" viewBox="0 0 13 13" aria-hidden="true" style="vertical-align:-1px;margin-right:6px"><path d="M2 7l3 3 6-7" fill="none" stroke="currentColor" stroke-width="2"/></svg>pasted'
      : 'let&nbsp;go&nbsp;to&nbsp;paste';
    if (on && !reduce) { paste.classList.remove('flash'); void paste.offsetWidth; paste.classList.add('flash'); }
    if (reduce) jaw.style.transform = `rotate(${on ? 0 : 14}deg)`;
  }, { threshold: 0.9 });
  atEnd.observe(paste);

  // live demo, only where the browser has speech recognition
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const box = document.getElementById('try');
  if (!SR) return;
  box.hidden = false;
  const btn = document.getElementById('talk');
  const said = document.getElementById('said');
  const note = document.getElementById('note');
  const fill = /^(um+|uh+|er+|erm)$/i;
  let rec = null, finals = '';

  const render = (interim) => {
    const clean = (t) => t.split(/\s+/).filter(Boolean);
    const out = document.createDocumentFragment();
    const add = (words, cls) => {
      let prev = '';
      for (const w of words) {
        const span = document.createElement('span');
        const dropped = fill.test(w) || w.toLowerCase() === prev.toLowerCase();
        span.className = dropped ? 'f' : cls;
        span.textContent = w + ' ';
        out.appendChild(span);
        prev = w;
      }
    };
    add(clean(finals), '');
    add(clean(interim), 'i');
    said.replaceChildren(out);
  };

  const stop = () => { if (rec) rec.stop(); };
  const start = () => {
    finals = ''; note.textContent = ''; said.textContent = '';
    rec = new SR();
    rec.continuous = true; rec.interimResults = true; rec.lang = 'en-GB';
    rec.onresult = (ev) => {
      let interim = '';
      for (let i = ev.resultIndex; i < ev.results.length; i++) {
        const r = ev.results[i];
        if (r.isFinal) finals += r[0].transcript + ' '; else interim += r[0].transcript;
      }
      render(interim);
    };
    rec.onerror = (ev) => {
      note.textContent = ev.error === 'not-allowed' || ev.error === 'service-not-allowed'
        ? "the browser wouldn't give this page the microphone. opening the file straight from disk often does that."
        : ev.error === 'no-speech' ? "didn't hear anything." : 'the browser stopped listening (' + ev.error + ').';
    };
    rec.onend = () => {
      btn.setAttribute('aria-pressed', 'false');
      btn.textContent = 'hold to talk';
      const kept = finals.split(/\s+/).filter((w, i, a) => w && !fill.test(w) && (i === 0 || w.toLowerCase() !== a[i - 1].toLowerCase())).join(' ');
      if (kept) said.textContent = kept;
      rec = null;
    };
    try { rec.start(); btn.setAttribute('aria-pressed', 'true'); btn.textContent = 'let go to paste'; } catch (e) { rec = null; }
  };

  btn.addEventListener('pointerdown', (e) => { e.preventDefault(); if (!rec) start(); });
  btn.addEventListener('pointerup', stop);
  btn.addEventListener('pointerleave', stop);
  btn.addEventListener('keydown', (e) => { if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) { e.preventDefault(); rec ? stop() : start(); } });
  addEventListener('keydown', (e) => { if (e.key === 'Escape' && rec) { finals = ''; rec.abort(); said.textContent = ''; } });
})();
