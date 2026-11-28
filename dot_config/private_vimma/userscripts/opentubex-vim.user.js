// ==UserScript==
// @name         OpenTubeX vim keys
// @namespace    https://github.com/zalewskigrzegorz/dotfiles
// @version      1.0
// @description  Vim keys on an OpenTubeX (opentubex.mrglaszki.com) video page, same as youtube-vim: h/l seek 5 s, b/w seek 30 s, j/k speed, - = volume, space play and pause. Esc hands the keys back to Vimma.
// @match        https://opentubex.mrglaszki.com/*
// @run-at       document-idle
// @grant        none
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/opentubex-vim.user.js
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/opentubex-vim.user.js
// ==/UserScript==

// OpenTubeX is a hash-routed SPA: a video page is #/watch/<id>
const video = () => document.querySelector("video");
const onWatch = () => location.hash.startsWith("#/watch");
const typing = (t) => t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName);
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));

function seek(seconds) {
  video().currentTime += seconds;
  return `${seconds > 0 ? "+" : ""}${seconds} s`;
}

function volume(step) {
  const v = video();
  v.muted = false;
  v.volume = clamp(Math.round(v.volume * 100 + step) / 100, 0, 1);
  return `vol ${Math.round(v.volume * 100)}%`;
}

function speed(direction) {
  const v = video();
  v.playbackRate = clamp(v.playbackRate + direction * 0.25, 0.25, 4);
  return `${v.playbackRate}x`;
}

function toggle() {
  const v = video();
  if (v.paused) v.play();
  else v.pause();
  return v.paused ? "pauza" : "play";
}

const KEYS = {
  h: () => seek(-5),
  l: () => seek(5),
  b: () => seek(-30),
  w: () => seek(30),
  j: () => speed(-1),
  k: () => speed(1),
  "-": () => volume(-5),
  "=": () => volume(5),
  " ": toggle,
};

const toast = (text) => {
  const t = Object.assign(document.createElement("div"), { textContent: text });
  t.style.cssText =
    "position:fixed;bottom:16px;left:16px;z-index:99999;padding:4px 10px;border-radius:6px;" +
    "background:#000c;color:#fff;font:13px/1.4 monospace;pointer-events:none";
  (document.fullscreenElement ?? document.body).append(t);
  setTimeout(() => t.remove(), 700);
};

// Vimma eats single letters in normal mode and goes to insert when a text box has the focus,
// so on a video page this hidden box takes it. Esc gives the keys back to Vimma, i returns them.
const box = Object.assign(document.createElement("div"), { id: "otx-vim-keys", tabIndex: -1 });
box.setAttribute("role", "textbox");
box.setAttribute("aria-label", "opentubex vim keys");
box.style.cssText = "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none";
document.body.append(box);

// keypress and keyup are swallowed too, so OpenTubeX's own shortcuts never fire twice
for (const type of ["keydown", "keypress", "keyup"]) {
  window.addEventListener(
    type,
    (e) => {
      if (!onWatch() || e.metaKey || e.ctrlKey || e.altKey || e.isComposing || typing(e.target)) return;
      const action = KEYS[e.key];
      if (!action || !video()) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      if (type !== "keydown") return;
      toast(action());
      if (document.activeElement !== box) box.focus({ preventScroll: true });
    },
    true,
  );
}

// a click on the video moves the focus into the player: take it back so the keys keep working
document.addEventListener("focusin", (e) => {
  if (onWatch() && e.target !== box && !typing(e.target) && e.target.closest?.("video, .ftVideoPlayer, .videoPlayer")) {
    box.focus({ preventScroll: true });
  }
});

let lastUrl = "";
setInterval(() => {
  const url = location.hash;
  if (url === lastUrl) return;
  lastUrl = url;
  if (onWatch()) box.focus({ preventScroll: true });
  else if (document.activeElement === box) box.blur();
}, 300);
