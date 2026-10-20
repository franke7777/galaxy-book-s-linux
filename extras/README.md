# Extras: small desktop glue

Optional helpers that connect the hardware fixes to a Sway desktop. Install the scripts to `~/.local/bin`.

| File | Purpose |
|---|---|
| [sway-hardware.conf](sway-hardware.conf) | hardware-related Sway lines: swayidle timings, brightness / volume / keyboard light keys, touchpad, mic gain |
| [books-idle](books-idle) | called by swayidle: 5 min screen off (backlight 15 %, `output * power off`, keyboard light off), 20 min hibernate on battery, on AC wait until unplugged. `simpledrm` swallows the first `output * power on` after turning off, so `wake` repeats it until `power: true` |
| [bl-osd](bl-osd), [kbd-osd](kbd-osd) | change brightness / keyboard light and show a swayosd indicator |
| [books-mic-gain](books-mic-gain) | set the DMIC source to volume 2.0 (`MIC_GAIN`), the node name changes per boot |
| [bash_profile-gpu.sh](bash_profile-gpu.sh) | start Sway on tty1, GPU rendering when books-i915 is ready, otherwise Pixman |
| [firefox-user.js](firefox-user.js) | VA-API on, AV1 off, UI scale for 1920x1080 on 13.3" |

For waybar, a custom module with `"exec": "books-backlight watch"` shows the brightness without polling scripts or signals.
