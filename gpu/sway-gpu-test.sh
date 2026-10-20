#!/bin/sh
# Test: Sway renders on the Lakefield GPU (i915, renderD128), scanout still through simpledrm (card0).
# Start on tty2. Back to the normal session: Ctrl+Alt+F1. Quit: Super+Shift+E.
export WLR_RENDERER=gles2 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 WLR_DRM_DEVICES=/dev/dri/card0 MOZ_ENABLE_WAYLAND=1
LOG=${LOG:-$HOME/sway-gpu-test.log}
echo "=== $(date) start" > "$LOG"
sway -d >> "$LOG" 2>&1
echo "=== $(date) end rc=$?" >> "$LOG"
echo "Sway exited, log: $LOG (back: Ctrl+Alt+F1)"
