// ==UserScript==
// @name         YouTube: space does not play
// @namespace    https://github.com/zalewskigrzegorz/dotfiles
// @version      1.0
// @description  Space is Vimma's leader, so YouTube's player must not see it outside text fields. k still plays and pauses.
// @match        https://www.youtube.com/*
// @run-at       document-start
// @grant        none
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-space-no-play.user.js
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/dot_config/private_vimma/userscripts/youtube-space-no-play.user.js
// ==/UserScript==

const typing = (t) => t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName);

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
