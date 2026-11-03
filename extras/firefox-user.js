// Put into your Firefox profile directory as user.js.
// Hardware video decoding on the Lakefield GPU (VA-API, iHD), requires books-i915 (see gpu/)
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
// Gen 11 has no AV1 decoder: make YouTube deliver VP9/H.264 instead of AV1 decoded on the CPU
user_pref("media.av1.enabled", false);
// 1920x1080 on 13.3", no Sway scaling: slightly larger UI
user_pref("layout.css.devPixelsPerPx", "1.3");
// WebRender on the GPU. After a single "GPU HANG ... in Renderer" (recovered) this was
// set to true for a while, but the real freezes turned out to be the eUFS (see docs/ufs.md).
// If you see GPU hangs from Firefox in `journalctl -k`, set it to true (CPU rendering).
user_pref("gfx.webrender.software", false);
