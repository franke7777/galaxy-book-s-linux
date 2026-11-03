# Extras: small desktop glue

Optional helpers that connect the hardware fixes to a Sway desktop. Install the scripts to `~/.local/bin`.

| File | Purpose |
|---|---|
| [sway-hardware.conf](sway-hardware.conf) | hardware-related Sway lines: swayidle timings, brightness / volume / keyboard light keys, touchpad, mic gain |
| [books-idle](books-idle) | called by swayidle: 5 min screen off (backlight 15 %, `output * power off`, keyboard light off), 20 min hibernate on battery, on AC wait until unplugged. `simpledrm` swallows the first `output * power on` after turning off, so `wake` repeats it until `power: true` |
| [bl-osd](bl-osd), [kbd-osd](kbd-osd) | change brightness / keyboard light and show a swayosd indicator |
| [books-mic-gain](books-mic-gain) | set the DMIC source to volume 2.0 (`MIC_GAIN`), the node name changes per boot |
| [bash_profile-gpu.sh](bash_profile-gpu.sh) | start Sway on tty1, GPU rendering when books-i915 is ready, otherwise Pixman |
| [firefox-user.js](firefox-user.js) | VA-API on, AV1 off, UI scale for 1920x1080 on 13.3", WebRender on the GPU |
| [books-launch](books-launch) | start Firefox/Thunderbird from a key binding with an instant "starting …" notification that disappears when the window shows up; `--focus` jumps to an existing window instead |

For waybar, a custom module with `"exec": "books-backlight watch"` shows the brightness without polling scripts or signals.

## Faster app start on Lakefield

The i5-L16G7 has one fast core and four small ones at 1.4 GHz, so Firefox and Thunderbird will always need a few seconds. What helped:

- **Thunderbird:** turn off global search indexing (`mailnews.database.global.indexer.enabled = false`, the quick filter still works), don't log in to rarely used accounts at startup (`mail.server.serverN.login_at_startup` / `check_new_mail = false`), and limit offline sync to recent mail (`mail.server.serverN.autosync_max_age_days = 90`). Edit `prefs.js` only while Thunderbird is closed.
- **Firefox:** keep WebRender on the GPU (see `firefox-user.js`), few extensions.
- **Feedback:** `books-launch` so a key press is visibly acknowledged.
