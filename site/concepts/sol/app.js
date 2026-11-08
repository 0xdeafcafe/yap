(() => {
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const topJaw = document.querySelector('#tTop');
  const key = document.querySelector('#tKey');
  const toy = document.querySelector('.toy');
  const wind = document.querySelector('#wind');
  let frame = 0;
  let windingUntil = 0;
  let lastScroll = scrollY;
  let scrolledUntil = 0;
  let visible = true;

  function resetTeeth() {
    topJaw?.removeAttribute('transform');
    key?.removeAttribute('transform');
  }
  function animate(now) {
    frame = 0;
    if (reduced.matches || !visible || now > Math.max(windingUntil, scrolledUntil)) {
      resetTeeth();
      return;
    }
    const angle = -4 - (Math.sin(now / 43) + 1) * 4;
    topJaw?.setAttribute('transform', `rotate(${angle} 112 218)`);
    key?.setAttribute('transform', `scale(${Math.cos(now / 110)} 1)`);
    frame = requestAnimationFrame(animate);
  }
  function start() {
    if (!frame && !reduced.matches && visible) frame = requestAnimationFrame(animate);
  }
  wind.addEventListener('click', () => {
    if (reduced.matches) {
      wind.querySelector('span').textContent = 'wound up. ready to yap.';
      return;
    }
    windingUntil = performance.now() + 1200;
    start();
  });
  addEventListener('scroll', () => {
    const distance = Math.abs(scrollY - lastScroll);
    lastScroll = scrollY;
    if (distance > 0 && visible) {
      scrolledUntil = performance.now() + 180;
      start();
    }
  }, { passive: true });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      if (!visible) resetTeeth();
      else if (performance.now() < Math.max(windingUntil, scrolledUntil)) start();
    }).observe(toy);
  }

  const demo = document.querySelector('#demo');
  const still = document.querySelector('#demo-still');
  const toggle = document.querySelector('#demo-toggle');
  let playing = false;
  toggle.hidden = false;
  function setPlaying(next) {
    playing = next;
    demo.hidden = !playing;
    still.hidden = playing;
    toggle.textContent = playing ? 'pause the recording' : 'play the recording';
    toggle.setAttribute('aria-pressed', String(playing));
  }
  setPlaying(false);
  toggle.addEventListener('click', () => setPlaying(!playing));
  // The real recording is the only moving demonstration. It never auto-plays.
  reduced.addEventListener('change', () => {
    resetTeeth();
    if (reduced.matches) setPlaying(false);
  });

  const copy = document.querySelector('#copy');
  const status = document.querySelector('#copy-status');
  const commands = document.querySelector('#install-commands');
  copy.hidden = false;
  copy.addEventListener('click', async () => {
    const text = commands.textContent.trim();
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(text);
      status.textContent = 'copied both commands.';
    } catch {
      const range = document.createRange();
      range.selectNodeContents(commands);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      status.textContent = 'commands selected. press ⌘C to copy.';
    }
  });
})();
