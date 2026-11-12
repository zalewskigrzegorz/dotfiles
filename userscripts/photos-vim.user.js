// ==UserScript==
// @name         Photos vim keys
// @namespace    zalewskigrzegorz
// @version      6
// @description  Vim keys in the Google Photos preview: h/l previous/next, dd trash without the confirm dialog, u undo. The grid keeps Vimma's own keys.
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
  more: ['Więcej opcji', 'More options'],
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const visible = (el) => {
  const r = el.getBoundingClientRect();
  return r.width > 0 && r.height > 0;
};
const onScreen = (el) => {
  const r = el.getBoundingClientRect();
  return r.width > 0 && r.height > 0 && r.right > 0 && r.bottom > 0 && r.left < innerWidth && r.top < innerHeight;
};
const labelOf = (el) => (el.getAttribute('aria-label') ?? el.getAttribute('data-tooltip') ?? el.textContent).trim();
const byLabel = (labels, root = document) => {
  const hit = [...root.querySelectorAll('button, [role=button], [aria-label], [data-tooltip]')].find(
    (el) => onScreen(el) && labels.includes(labelOf(el))
  );
  return hit?.closest('button, [role=button]') ?? hit;
};
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
const inPreview = () => location.pathname.includes('/photo/');

const waitFor = async (find) => {
  for (let i = 0; i < 20; i++) {
    const el = find();
    if (el) return el;
    await sleep(100);
  }
};

async function trash() {
  let button = byLabel(LABEL.trash);
  if (!button) {
    // inside an album the trash sits in the "More options" menu
    if (!press(byLabel(LABEL.more))) return toast('dd: nie widzę kosza ani menu');
    button = await waitFor(() =>
      [...document.querySelectorAll('[role=menuitem]')].find(
        (el) => onScreen(el) && LABEL.trash.some((l) => el.textContent.includes(l))
      )
    );
    if (!button) return toast('dd: w menu nie ma kosza');
  }
  press(button);
  for (let i = 0; i < 20; i++) {
    await sleep(100);
    const dialog = [...document.querySelectorAll('[role=dialog], [role=alertdialog]')].find(visible);
    const ok = dialog && byLabel(LABEL.trash, dialog);
    if (ok) return press(ok);
  }
  toast('dd: kliknięty kosz, ale nie było okna potwierdzenia');
}

const KEYS = 'hldu';
const plain = (e) =>
  !(e.metaKey || e.ctrlKey || e.altKey || e.isComposing) &&
  KEYS.includes(e.key) &&
  !e.target.closest?.('input, textarea, [contenteditable=""], [contenteditable="true"]');

let lastD = 0;
function handle(key) {
  switch (key) {
    case 'h': return press(byLabel(LABEL.prev));
    case 'l': return press(byLabel(LABEL.next));
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
    if (!inPreview() || !plain(e) || !run(e.key)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
  }, true);

  // Vimma keeps its own keys in normal mode and hands them to the page in insert mode, which it
  // enters when a text box gets the focus. In the photo preview this box takes the focus, so the
  // keys above reach the page; in the grid it lets go and Vimma's hjkl work as before.
  const box = Object.assign(document.createElement('div'), { tabIndex: -1 });
  box.setAttribute('role', 'textbox');
  box.setAttribute('aria-label', 'photos vim keys');
  box.style.cssText = 'position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none';
  document.body.append(box);
  let lastPath = '';
  setInterval(() => {
    if (location.pathname === lastPath) return;
    lastPath = location.pathname;
    if (inPreview()) box.focus({ preventScroll: true });
    else if (document.activeElement === box) box.blur();
  }, 300);
}
