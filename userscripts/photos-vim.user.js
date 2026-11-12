// ==UserScript==
// @name         Photos vim keys
// @namespace    zalewskigrzegorz
// @version      2
// @description  Vim keys in Google Photos: h/l previous/next photo, j/k scroll, dd trash without the confirm dialog, u undo.
// @match        https://photos.google.com/*
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

let lastD = 0;
addEventListener(
  'keydown',
  (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey || e.isComposing) return;
    if (e.target.closest?.('input, textarea, [contenteditable=""], [contenteditable="true"]')) return;
    let handled = true;
    switch (e.key) {
      case 'h': handled = press(byLabel(LABEL.prev)); break;
      case 'l': handled = press(byLabel(LABEL.next)); break;
      case 'j': scroller().scrollBy({ top: 300 }); break;
      case 'k': scroller().scrollBy({ top: -300 }); break;
      case 'u': handled = press(byLabel(LABEL.undo)); break;
      case 'd':
        if (Date.now() - lastD < 500) {
          lastD = 0;
          trash();
        } else lastD = Date.now();
        break;
      default: handled = false;
    }
    if (e.key.length === 1 && 'hjkldu'.includes(e.key)) toast(handled ? `vim: ${e.key}` : `vim: ${e.key} (brak przycisku)`);
    if (handled) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  },
  true
);
