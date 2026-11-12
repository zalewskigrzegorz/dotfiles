// ==UserScript==
// @name         TikToki → album
// @namespace    zalewskigrzegorz
// @version      1
// @description  Adds new TikTok downloads (file name "v" + 31 chars + ".mp4") to the album "tiktoki-podglad". Never deletes anything. Needs Google Photos Toolkit (GPTK).
// @match        https://photos.google.com/*
// @grant        unsafeWindow
// @grant        GM_getValue
// @grant        GM_setValue
// @run-at       document-idle
// @updateURL    https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/userscripts/tiktok-to-album.user.js
// @downloadURL  https://raw.githubusercontent.com/zalewskigrzegorz/dotfiles/master/userscripts/tiktok-to-album.user.js
// ==/UserScript==

const ALBUM = 'tiktoki-podglad';
const TIKTOK = /^v[0-9a-z]{31}\.mp4$/; // TikTok CDN video id, e.g. v26044gc0000d7stsg7og65v2ftve6jg.mp4
const EVERY_MS = 6 * 3600e3;
const OVERLAP_MS = 2 * 86400e3; // look two days back: uploads from the phone land late

(async () => {
  const last = GM_getValue('lastRun', 0);
  if (Date.now() - last < EVERY_MS) return;

  let api;
  for (let i = 0; i < 60 && !(api = unsafeWindow.gptkApi); i++) await new Promise((r) => setTimeout(r, 1000));
  const utils = unsafeWindow.gptkApiUtils;
  if (!api || !utils) return console.warn('[tiktok-album] GPTK not loaded, skipped');

  // newest uploads first; the first run scans the whole library
  const since = last ? last - OVERLAP_MS : 0;
  const videos = [];
  let page = null;
  do {
    const p = await api.getItemsByUploadedDate(page);
    const items = p.items ?? [];
    videos.push(...items.filter((it) => it.duration && it.creationTimestamp >= since));
    if (items.length && items[items.length - 1].creationTimestamp < since) break;
    page = p.nextPageId;
  } while (page);

  let hits = [];
  if (videos.length) {
    const info = await utils.getBatchMediaInfoChunked(videos);
    const names = new Map(info.map((i) => [i.mediaKey, i.fileName ?? '']));
    // remembered, so a TikTok you took out of the album to keep is never added again
    const added = new Set(GM_getValue('added', []));
    hits = videos.filter((v) => TIKTOK.test(names.get(v.mediaKey) ?? '') && !added.has(v.mediaKey));
    if (hits.length) {
      let album = (await utils.getAllAlbums()).find((a) => a.title === ALBUM);
      if (!album) album = { title: ALBUM, isShared: false, itemCount: 0, mediaKey: await api.createAlbum(ALBUM) };
      await utils.addToExistingAlbum(hits, album);
      hits.forEach((h) => added.add(h.mediaKey));
      GM_setValue('added', [...added]);
    }
  }
  GM_setValue('lastRun', Date.now());
  console.log(`[tiktok-album] ${videos.length} new videos checked, ${hits.length} TikToks added to "${ALBUM}"`);
})().catch((e) => console.error('[tiktok-album]', e));
