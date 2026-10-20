# Snippet for ~/.bash_profile: start Sway on tty1.
# With the Lakefield GPU (books-i915 + books-gpu-id): render on renderD128, scan out through simpledrm.
# Otherwise fall back to Pixman (software).
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
  export MOZ_ENABLE_WAYLAND=1
  sdrm=$(for c in /sys/class/drm/card[0-9]; do [ "$(basename "$(readlink -f "$c/device/driver")")" = simple-framebuffer ] && echo "/dev/dri/${c##*/}"; done)
  if [ -e /dev/dri/renderD128 ] && [ -n "$sdrm" ] && [ "$(cat /sys/bus/pci/devices/0000:00:02.0/device)" = 0x4e71 ]; then
    export WLR_RENDERER=gles2 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 WLR_DRM_DEVICES=$sdrm
  else
    export WLR_RENDERER=pixman
  fi
  exec sway
fi
