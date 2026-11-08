'use strict';
const tape = document.querySelector('#tape');
const columns = [...document.querySelectorAll('.column')];
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const hold = document.querySelector('#hold');
const replay = document.querySelector('#replay');
const transcript = document.querySelector('#transcript');
const pasted = document.querySelector('#pasted');
const status = document.querySelector('#demo-status');
const label = document.querySelector('#blob-label');
const sample = 'i was going to type all of this. then i remembered i could just say it.';
const chunks = ['i was going', 'i was going to type', 'i was going to type all of this.', 'i was going to type all of this. then i remembered', sample];
let timer;
let active = false;
let automatic = false;
let chunk = 0;
let pointerUsed = false;

function stopTimer() { clearInterval(timer); timer = undefined; }
function renderChunk() {
  transcript.textContent = chunks[chunk];
  transcript.style.fontSize = `${[48, 40, 32, 28, 24][chunk]}px`;
}
function start(auto = false) {
  stopTimer();
  active = true;
  automatic = auto;
  chunk = 0;
  hold.setAttribute('aria-pressed', 'true');
  replay.textContent = auto ? 'paste the sample' : 'sample playing';
  label.textContent = 'sample dictation';
  status.textContent = 'Sample dictation playing. No microphone is used.';
  // A phone cannot show the key and the listening column at once.
  // Keep the hold control in place; the separate replay control is in that column.
  if (reduced.matches) {
    chunk = chunks.length - 1;
    renderChunk();
    return;
  }
  renderChunk();
  timer = setInterval(() => {
    if (chunk < chunks.length - 1) { chunk += 1; renderChunk(); }
    else if (automatic) finish();
    else stopTimer();
  }, 700);
}
function finish() {
  if (!active) return;
  stopTimer();
  active = false;
  pasted.value = transcript.textContent;
  pasted.classList.add('fresh');
  setTimeout(() => pasted.classList.remove('fresh'), 300);
  hold.setAttribute('aria-pressed', 'false');
  label.textContent = 'pasted';
  replay.textContent = 'play the sample ↗';
  status.textContent = 'Sample pasted into the editable field.';
}
function cancel() {
  if (!active) return;
  stopTimer(); active = false;
  hold.setAttribute('aria-pressed', 'false');
  label.textContent = 'cancelled';
  replay.textContent = 'play the sample ↗';
  status.textContent = 'Sample cancelled. The editable field was left unchanged.';
}
hold.setAttribute('aria-pressed', 'false');
hold.addEventListener('pointerdown', e => {
  if (e.button !== 0) return;
  pointerUsed = true;
  hold.setPointerCapture(e.pointerId);
  start();
});
hold.addEventListener('pointerup', () => { finish(); });
hold.addEventListener('pointercancel', cancel);
hold.addEventListener('lostpointercapture', () => { if (active && !automatic) cancel(); });
hold.addEventListener('keydown', e => {
  if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) { e.preventDefault(); start(); }
});
hold.addEventListener('keyup', e => {
  if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); finish(); }
});
hold.addEventListener('click', e => {
  // Assistive technologies may activate a button without pointer or keyboard events.
  if (e.detail === 0 && !pointerUsed && !active) start(true);
  pointerUsed = false;
});
replay.addEventListener('click', () => active ? finish() : start(true));
document.addEventListener('keydown', e => { if (e.key === 'Escape') cancel(); });
window.addEventListener('blur', cancel);
document.addEventListener('visibilitychange', () => { if (document.hidden) cancel(); });

function moveTo(index) {
  const item = columns[Math.max(0, Math.min(index, columns.length - 1))];
  item.scrollIntoView({ behavior: reduced.matches ? 'instant' : 'smooth', block: 'nearest', inline: 'start' });
}
function currentColumn() {
  return columns.reduce((best, item, i) => Math.abs(item.offsetLeft - tape.scrollLeft) < Math.abs(columns[best].offsetLeft - tape.scrollLeft) ? i : best, 0);
}
document.querySelector('#previous').addEventListener('click', () => moveTo(currentColumn() - 1));
document.querySelector('#next').addEventListener('click', () => moveTo(currentColumn() + 1));
function updatePosition() {
  const max = tape.scrollWidth - tape.clientWidth;
  const fraction = max > 0 ? tape.scrollLeft / max : 0;
  document.querySelector('#progress').style.width = `${fraction * 100}%`;
  document.querySelector('#previous').disabled = tape.scrollLeft < 2;
  document.querySelector('#next').disabled = tape.scrollLeft >= max - 2;
  const links = [...document.querySelectorAll('.transport nav a')];
  let selected = links[0];
  for (const link of links) {
    if (document.querySelector(link.hash).offsetLeft <= tape.scrollLeft + 80) selected = link;
    link.removeAttribute('aria-current');
  }
  if (fraction > .99) selected = links[links.length - 1];
  selected.setAttribute('aria-current', 'location');
}
tape.addEventListener('scroll', updatePosition, {passive:true});
window.addEventListener('resize', updatePosition);
updatePosition();

const recordingButton = document.querySelector('#recording-toggle');
recordingButton.addEventListener('click', () => {
  const playing = recordingButton.getAttribute('aria-pressed') === 'true';
  const image = document.querySelector('#recording-slot img');
  image.src = playing ? 'demo-still.png' : 'demo.webp';
  recordingButton.setAttribute('aria-pressed', String(!playing));
  recordingButton.textContent = playing ? 'play recording' : 'stop recording';
});

document.querySelector('#copy').addEventListener('click', async () => {
  const text = document.querySelector('#commands').textContent;
  const feedback = document.querySelector('#copy-status');
  try {
    if (!navigator.clipboard) throw new Error('Clipboard unavailable');
    await navigator.clipboard.writeText(text);
    feedback.textContent = 'copied. paste both into terminal.';
  } catch {
    const selection = getSelection();
    const range = document.createRange();
    range.selectNodeContents(document.querySelector('#commands'));
    selection.removeAllRanges(); selection.addRange(range);
    feedback.textContent = 'commands selected. press ⌘C to copy.';
  }
});
