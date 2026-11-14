// ==UserScript==
// @name         YouTube vim keys
// @namespace    https://github.com/zalewskigrzegorz/dotfiles
// @version      1.0
// @description  Vim keys on a YouTube video page: h/l seek 5 s, b/w seek 30 s, j/k volume, < > speed, space play and pause. Esc hands the keys back to Vimma.
// @match        https://www.youtube.com/*
// @run-at       document-idle
// @grant        none
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-vim.user.js
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-vim.user.js
// ==/UserScript==

const video = () => document.querySelector("#movie_player video");
const onWatch = () => location.pathname === "/watch";
const typing = (t) => t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName);
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));

function seek(seconds) {
  video().currentTime += seconds;
  return `${seconds > 0 ? "+" : ""}${seconds} s`;
}

function volume(step) {
  const player = document.getElementById("movie_player");
  const next = clamp(player.getVolume() + step, 0, 100);
  player.unMute();
  player.setVolume(next);
  return `vol ${next}%`;
}

function speed(direction) {
  const v = video();
  // Enhancer for YouTube keeps its own copy of the speed and steps it on ctrl+wheel, so its handler goes first.
  const wheel = new WheelEvent("wheel", { ctrlKey: true, deltaY: -direction * 100, bubbles: true, cancelable: true });
  if (v.dispatchEvent(wheel)) v.playbackRate = clamp(v.playbackRate + direction * 0.25, 0.25, 4);
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
  j: () => volume(-5),
  k: () => volume(5),
  "<": () => speed(-1),
  ">": () => speed(1),
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

// Vimma keeps its own keys in normal mode and hands them to the page in insert mode, which it
// enters when a text box gets the focus. On a video page this box takes the focus. Esc gives the
// keys back to Vimma, and i returns them to the video.
const box = Object.assign(document.createElement("div"), { id: "yt-vim-keys", tabIndex: -1 });
box.setAttribute("role", "textbox");
box.setAttribute("aria-label", "youtube vim keys");
box.style.cssText = "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none";
document.body.append(box);

// keypress and keyup are swallowed too, so YouTube's own handlers never see a key handled here
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

// a click on the video gives the focus to the player: take it back, so the click also returns the keys
document.addEventListener("focusin", (e) => {
  if (onWatch() && e.target.id === "movie_player") box.focus({ preventScroll: true });
});

let lastUrl = "";
setInterval(() => {
  const url = location.pathname + location.search;
  if (url === lastUrl) return;
  lastUrl = url;
  if (onWatch()) box.focus({ preventScroll: true });
  else if (document.activeElement === box) box.blur();
}, 300);
