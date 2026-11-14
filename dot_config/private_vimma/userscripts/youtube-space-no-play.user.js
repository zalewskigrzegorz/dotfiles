// ==UserScript==
// @name         YouTube: space does not play
// @namespace    https://github.com/zalewskigrzegorz/dotfiles
// @version      1.1
// @description  Space is Vimma's leader, so YouTube's player must not see it outside text fields. k still plays and pauses.
// @match        https://www.youtube.com/*
// @run-at       document-start
// @grant        none
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-space-no-play.user.js
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-space-no-play.user.js
// ==/UserScript==

// yt-vim-keys is the box youtube-vim.user.js focuses on a video page: Vimma is in insert mode there, so space is free
const typing = (t) => t.isContentEditable || t.id === "yt-vim-keys" || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName);

// Window capture runs before YouTube's own listeners. No preventDefault: Vimma may check it.
for (const type of ["keydown", "keypress", "keyup"]) {
  window.addEventListener(
    type,
    (e) => {
      if (e.code === "Space" && !typing(e.target)) e.stopImmediatePropagation();
    },
    true,
  );
}
