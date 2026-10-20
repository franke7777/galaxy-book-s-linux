# GPU: Lakefield 8086:9840 as a render-only device

Without this, the display runs on `simpledrm` and everything renders on the CPU (llvmpipe / Pixman). Videos cost a lot of CPU and WebGL is unusable.

The Lakefield GPU is Gen 11 like Ice Lake, but `i915` has no entry for `9840`. Result of the experiments:

| Variant | Result |
|---|---|
| B: `9840` as Ice Lake for GT **and** display ([i915-lkf-9840-with-display-DEADEND.patch](i915-lkf-9840-with-display-DEADEND.patch)) | **Machine freezes completely**, power button only. Log: combo PHY calibration (`icl_get_procmon_ref_values`, 12 times), power well / fuse status `0x42000` never acknowledges, crash in `icl_tc_phy_hpd_live_status` (Lakefield has no ICL Type-C ports). The Ice Lake display code does not fit. |
| A: GT only with the **Ice Lake** profile (`icl_info`) | Loads, display stays, `renderD128` appears. But the render engine hangs on the first batch: `GPU HANG ecode 11:1:e757fefe`, rcs0 preemption timeout, IPEHR = `MI_BATCH_BUFFER_START`, "CS timestamp frequency: 0 Hz". |
| A: GT only with the **Elkhart Lake** profile (`ehl_info`, Gen 11 low power) | **Renders correctly.** [gltest.c](gltest.c) (EGL surfaceless, GLES2, many triangles at 1920x1080): image matches llvmpipe (same number of colored pixels, sum within 0.2 % rasterisation difference), **2677 fps instead of 75 fps** (about 35 times), no GPU hang. |

## What the final patch does

[../dkms/books-i915/i915-lkf.patch](../dkms/books-i915/i915-lkf.patch), built by the DKMS package `books-i915`:

- `INTEL_VGA_DEVICE(0x9840, &ehl_info)` in `i915_pci.c`, GT only. No display device entry, so i915 does not drive the panel.
- `aperture_remove_conflicting_pci_devices()` is skipped for `9840`: `simpledrm` keeps the BOOTFB.
- GGTT range 0 to 8 MB is reserved (`drm_mm_reserve_node`, `I915_COLOR_UNEVICTABLE`): the BOOTFB that `simpledrm` scans out lives at GGTT 0 (aperture `0xa0000000`), the firmware PTEs must stay.
- No stolen memory (it contains the BOOTFB).
- **No runtime PM** for `9840` (`pm_runtime_allow` skipped). With runtime PM, i915 put `00:02.0` into D3 as soon as the GPU went idle, and since `simpledrm` scans out from the same PCI device, the picture froze while the system kept running. With `power/control = on` the device stays active while the GT itself still sleeps (RC6, "GT awake? no").
- `I915_PARAM_CHIPSET_ID` reports `0x4e71` (Elkhart/Jasper Lake) for `9840`, so that `iHD` (VA-API) accepts it. iHD reads the ID through this ioctl, not from sysfs (checked with strace).

## Mesa: device ID bind mount

Mesa does not know `0x9840` ("Driver does not support the 0x9840 PCI ID"), and `INTEL_DEVID_OVERRIDE` has no effect in Mesa 26.2. libdrm reads the ID from `/sys/bus/pci/devices/0000:00:02.0/device`, so [books-gpu-id.service](books-gpu-id.service) bind-mounts a file containing `0x4e71` ([device-id](device-id)) over it. The kernel still sees `9840`. Mesa then reports "Mesa Intel(R) UHD Graphics (JSL)", OpenGL 4.6.

## Sway on the GPU, scanout through simpledrm

```
WLR_RENDERER=gles2 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 WLR_DRM_DEVICES=/dev/dri/card0
```

(`card0` = the `simpledrm` card; [../extras/bash_profile-gpu.sh](../extras/bash_profile-gpu.sh) looks it up by driver.) wlroots 0.20 renders with iris directly into LINEAR GBM buffers of `simpledrm` (XR24), no extra copy in the compositor; `simpledrm` then only copies into the BOOTFB. The hardware cursor does not work ("Failed to render cursor buffer", `simpledrm` has no cursor plane), the software cursor is fine. Test script: [sway-gpu-test.sh](sway-gpu-test.sh) (second instance on tty2).

## VA-API

With the `CHIPSET_ID` change, `vainfo` loads **iHD** (intel-media-driver 26.3.5) and offers decode for H.264, HEVC (8/10 bit, 4:2:2, 4:4:4) and VP9. No AV1 (Gen 11). ffmpeg, 10 s of 1080p30: H.264 0.32 s CPU instead of 3.3 s, VP9 0.25 s instead of 2.7 s (about 10 times less CPU), no hangs. mpv with `hwdec=vaapi` reports "Using hardware decoding (vaapi)". For Firefox see [../extras/firefox-user.js](../extras/firefox-user.js): VA-API on, hardware decoding forced, **AV1 off** (otherwise YouTube serves AV1 and Firefox decodes it on the CPU).

## Install

1. DKMS package (build takes about 3.5 minutes on the device):
   ```
   sudo cp -r dkms/books-i915 /usr/src/books-i915-1.0 && sudo dkms install books-i915/1.0
   ```
   The module lands in `updates/dkms/i915.ko.zst` and loads by modalias.
2. Remove `kms` from `HOOKS` in `/etc/mkinitcpio.conf` and run `sudo mkinitcpio -P`. i915 then loads only after root is mounted, the UFS boot path stays untouched.
3. Device ID for Mesa:
   ```
   sudo install -Dm644 gpu/device-id /etc/books-gpu/device-id
   sudo install -m644 gpu/books-gpu-id.service /etc/systemd/system/
   sudo systemctl enable books-gpu-id.service
   ```
4. Use [../extras/bash_profile-gpu.sh](../extras/bash_profile-gpu.sh) in `~/.bash_profile`: GLES on `renderD128` when the GPU is ready, otherwise Pixman.
5. Packages: `mesa`, `intel-media-driver`, `libva-utils` (for `vainfo`).

**Emergency:** GRUB menu, `e`, append `module_blacklist=i915` to the `linux` line. Everything is back to Pixman.

## Test tools

- [i915-test.sh](i915-test.sh): load a patched `i915.ko` by hand with a dead-man switch: if you do not `touch /tmp/i915-ok` within 300 s, it syncs and hard-reboots through SysRq. Run it via `systemd-run` so it survives a frozen session.
- [gltest.c](gltest.c): `cc -O2 gltest.c -o gltest -lEGL -lGLESv2 && ./gltest 500`. Compare the output with `LIBGL_ALWAYS_SOFTWARE=1 ./gltest 500`.
- [sway-gpu-test.sh](sway-gpu-test.sh): start a GPU-rendered Sway on tty2, log in `~/sway-gpu-test.log`.

## Open

- Vulkan not tested.
- Warning on unload in `i915_exit` (the static GGTT node is not released). Harmless, unloading is not needed in normal use.
- Xwayland not tested.
