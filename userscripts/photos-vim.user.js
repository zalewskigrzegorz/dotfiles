// ==UserScript==
// @name         Photos vim keys
// @namespace    zalewskigrzegorz
// @version      3
// @description  Vim keys in Google Photos: h/l previous/next photo, j/k scroll, dd trash without the confirm dialog, u undo.
// @match        https://photos.google.com/*
// @match        https://youtube.googleapis.com/embed/*
// @grant        none
// @run-at       document-idle
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/userscripts/photos-vim.user.js
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/userscripts/photos-vim.user.js
// ==/UserScript==

// Photos ignores synthetic key events, so every key clicks the page's own button, found by its label.
const LABEL = {
  prev: ['Wyświetl poprzednie zdjęcie', 'View previous photo'],
  next: ['Wyświetl następne zdjęcie', 'View next photo'],
  trash: ['Przenieś do kosza', 'Move to trash'],
  undo: ['Cofnij', 'Undo'],
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const visible = (el) => {
  const r = el.getBoundingClientRect();
  return r.width > 0 && r.height > 0;
};
const byLabel = (labels, root = document) =>
  [...root.querySelectorAll('button, [role=button], [aria-label]')].find(
    (el) => visible(el) && labels.includes((el.getAttribute('aria-label') ?? el.textContent).trim())
  );
const press = (el) => {
  if (!el) return false;
  const r = el.getBoundingClientRect();
  const at = { clientX: r.x + r.width / 2, clientY: r.y + r.height / 2, button: 0, pointerId: 1, isPrimary: true };
  for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
    const down = type.endsWith('down');
    const Ev = type.startsWith('pointer') ? PointerEvent : MouseEvent;
    el.dispatchEvent(new Ev(type, { bubbles: true, cancelable: true, view: window, buttons: down ? 1 : 0, ...at }));
  }
  return true;
};
const toast = (text) => {
  const t = Object.assign(document.createElement('div'), { textContent: text });
  t.style.cssText = 'position:fixed;bottom:16px;left:16px;z-index:99999;padding:4px 10px;border-radius:6px;' +
    'background:#000c;color:#fff;font:13px/1.4 monospace;pointer-events:none';
  document.body.append(t);
  setTimeout(() => t.remove(), 700);
};
const scroller = () => {
  let el = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
  while (el && !(el.scrollHeight > el.clientHeight + 10 && /auto|scroll/.test(getComputedStyle(el).overflowY)))
    el = el.parentElement;
  return el ?? document.scrollingElement;
};

async function trash() {
  if (!press(byLabel(LABEL.trash))) return;
  for (let i = 0; i < 20; i++) {
    await sleep(100);
    const dialog = [...document.querySelectorAll('[role=dialog], [role=alertdialog]')].find(visible);
    const ok = dialog && byLabel(LABEL.trash, dialog);
    if (ok) return press(ok);
  }
}

const KEYS = 'hjkldu';
const plain = (e) =>
  !(e.metaKey || e.ctrlKey || e.altKey || e.isComposing) &&
  KEYS.includes(e.key) &&
  !e.target.closest?.('input, textarea, [contenteditable=""], [contenteditable="true"]');

let lastD = 0;
function handle(key) {
  switch (key) {
    case 'h': return press(byLabel(LABEL.prev));
    case 'l': return press(byLabel(LABEL.next));
    case 'j': scroller().scrollBy({ top: 300 }); return true;
    case 'k': scroller().scrollBy({ top: -300 }); return true;
    case 'u': return press(byLabel(LABEL.undo));
    case 'd':
      if (Date.now() - lastD < 500) {
        lastD = 0;
        trash();
      } else lastD = Date.now();
      return true;
  }
  return false;
}

if (location.hostname === 'youtube.googleapis.com') {
  // a video plays in this embedded player and keeps the focus: hand the keys up to Photos
  if (window.top !== window)
    addEventListener('keydown', (e) => {
      if (!plain(e)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      parent.postMessage({ photosVim: e.key }, 'https://photos.google.com');
    }, true);
} else {
  const run = (key) => {
    const handled = handle(key);
    toast(handled ? `vim: ${key}` : `vim: ${key} (brak przycisku)`);
    return handled;
  };
  addEventListener('message', (e) => {
    if (e.origin === 'https://youtube.googleapis.com' && KEYS.includes(e.data?.photosVim)) run(e.data.photosVim);
  });
  addEventListener('keydown', (e) => {
    if (!plain(e) || !run(e.key)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
  }, true);
}
