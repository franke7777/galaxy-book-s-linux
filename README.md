<p align="center"><img src="docs/banner.svg" alt="Linux on the Samsung Galaxy Book S (Intel Lakefield)" width="100%"></p>

# Arch Linux on the Samsung Galaxy Book S (Intel Lakefield)

Patches, services and notes to run Arch Linux from the **internal eUFS** of the Samsung Galaxy Book S with the Intel Lakefield CPU (model **NP767XCM / 767XCL / SM-W767**, Core i5-L16G7). Almost nothing on this laptop works with a stock kernel. With the pieces in this repository nearly everything does, except the camera.

Everything here was developed and tested on one device with Arch Linux, kernel `linux 7.2.9.arch1`, BIOS P07AJD (2020), Secure Boot off. The desktop used was Sway, but only the `extras/` folder is Sway specific.

> **Read the [disclaimer](#disclaimer) first.** The root file system lives on the eUFS, and the eUFS only works with a patched driver. A kernel update without the patched module means a system that does not boot. Keep a live stick around.

## The story

This started in August 2026 with a simple question: can this little laptop run Linux at all? The first answer was "barely". Fedora booted from an external SSD, but with software rendering only, no battery reading, no sound, no brightness control and an internal disk that hung on every boot.

Over the next weeks it turned into a long puzzle, one piece at a time. The internal eUFS only became stable after capping its link at HS-G3. The battery turned out to hide behind the Integrated Sensor Hub. The GPU renders fine once i915 treats it as an Elkhart Lake chip and leaves the display alone. The speakers stayed silent until a single codec register, found by emulating the Windows Realtek driver, released the amplifiers from reset. The lid switch is a sensor that nobody listens to by default. Every one of these took evenings of reading ACPI tables, kernel source and Windows driver packages, plenty of dead ends and more than a few hard reboots.

In October Windows was wiped and Arch Linux moved onto the internal disk for good. Since then this is a daily driver: suspend, hibernate, sound, microphone, keyboard light, brightness and hardware video decoding all work. The camera is the one piece that refused to cooperate, and its notes are here too, so nobody has to start from zero.

It was a lot of work, and honestly a lot of fun. If you own a Galaxy Book S and this helps you, that makes it even better.

## Status

| Component | Status | How | Details |
|---|---|---|---|
| Internal eUFS (root disk) | Works | `ufshcd-pci` patched to cap the link at HS-G3 (G4 breaks under load), DKMS + initramfs | [docs/ufs.md](docs/ufs.md), [dkms/](dkms/README.md) |
| Boot loader | Works | GRUB. systemd-boot shows its menu, then a black screen | [install/](install/README.md) |
| Battery / AC adapter | Works | ISH PCI ID `98fc` via `new_id` + `INT3538` added to `intel_ishtp_eclite` | [battery/](battery/README.md) |
| Bluetooth | Works | `hci_intel` serdev series for the CcP controller (upstream patches by Cai Yu) + one missing `set_drvdata` | [dkms/](dkms/README.md) |
| Wi-Fi (Intel AX200) | Works | stock kernel | |
| GPU rendering (OpenGL, VA-API) | Works | `i915` as render-only GPU with the Elkhart Lake profile, display stays on `simpledrm`, Mesa sees the GPU as JSL | [gpu/](gpu/README.md) |
| Display brightness | Works | daemon that drives the GPU PWM register directly | [backlight/](backlight/README.md) |
| Speakers | Works | amplifier init sequence derived from the Windows Realtek driver | [audio/](audio/README.md) |
| Headphone jack (output) | Works | stock ALC298 | [audio/](audio/README.md) |
| Built-in microphone (DMIC) | Works | AVS DSP driver with the Windows SST firmware (you have to fetch it yourself) | [microphone/](microphone/README.md) |
| Keyboard backlight + Fn+F9 | Works | `samsung_galaxybook` reloaded after the ISH is up, Fn+F9 read from hidraw | [kbdlight/](kbdlight/README.md) |
| Lid switch | Works | ISH "Lid Closed Detection Sensor" mirrored to a uinput `SW_LID` | [lid/](lid/README.md) |
| Touchscreen (`STMD1234:00 06CB:1058`) | Works | stock `hid-multitouch` | [below](#touchscreen-and-input) |
| Touchpad, keyboard | Works | stock I2C HID | |
| Suspend (s2idle) | Works, but saves little | about 2 W in s2idle, Lakefield never reaches deep package states | [docs/power.md](docs/power.md) |
| Hibernate | Works | swap file + `resume_offset`, lid-close-on-battery policy | [hibernate/](hibernate/README.md) |
| Camera (IPU `9830`, sensor `HYV1A11`) | **Does not work** | IPU bootloader rejects the firmware with -21, even with the Lakefield firmware from the Windows driver | [camera/](camera/README.md) |
| Display through i915 | **Dead end** | Ice Lake display code freezes the machine. The panel stays on `simpledrm`, no hardware cursor | [gpu/](gpu/README.md) |
| Wake timer (rtcwake) | **Not possible** | `rtc0` is `acpi-tad` with caps `0x04` (clock only), no CMOS RTC | [docs/power.md](docs/power.md) |
| Deep idle / S0ix residency | **Unknown / not reached** | `intel_pmc_core` and `intel_idle` do not know Lakefield | [docs/power.md](docs/power.md) |
| Not tested | | microphone jack, external displays over USB-C, Vulkan, fingerprint reader, Xwayland | |

## Hardware IDs

| Part | ID |
|---|---|
| System | Samsung Galaxy Book S NP767XCM (767XCL), BIOS P07AJD, PCI subsystem `144d:c18b` |
| CPU | Intel Core i5-L16G7 (Lakefield, 1 Sunny Cove + 4 Tremont cores) |
| GPU | `8086:9840` at `00:02.0` (Gen 11 LP) |
| Camera IPU | `8086:9830` at `00:05.0`, sensor ACPI `HYV1A11` (SK Hynix) on I2C1 address `0x30` |
| Integrated Sensor Hub (ISH) | `8086:98fc` at `00:12.0` |
| UFS host controller | `8086:98fa` at `00:12.5`, device Samsung KLUEG8UHDB-C2D1 (eUFS 3.0, 256 GB) |
| HD audio / DSP | `8086:98c8` at `00:1f.3`, codec Realtek ALC298 (subsystem `144d:c18b`), four amps on I2C `0x38 0x39 0x3c 0x3d` behind the codec |
| EC-Lite (battery) | ACPI `INT3538` (`\_SB.ECLT`) |
| Bluetooth | Intel CcP over UART/serdev, ACPI `INT33E4`, firmware `intel/ibt-20-1-3.sfi` |
| Wi-Fi | Intel AX200 |
| Keyboard | ACPI `SLHD0001`, ENE `0CF2:9028`, I2C bus 3 |
| Touchscreen | `STMD1234:00 06CB:1058` (Synaptics, I2C) |

## Quick start

1. **BIOS:** Secure Boot off, Fast BIOS Mode off. The out-of-tree modules are unsigned.
2. **Do not install from the Arch ISO.** Its kernel loads the stock `ufshcd_pci`, the link goes to HS-G4 and breaks. Prepare a live stick (for example Ubuntu with persistence) where the eUFS is blacklisted and a G3-capped module is loaded instead: [install/live-stick/](install/README.md#1-live-stick-with-a-working-eufs).
3. From the live stick, run [install/stage1-bootstrap-pacstrap.sh](install/stage1-bootstrap-pacstrap.sh) (Arch bootstrap tarball, `pacstrap` onto the eUFS) and then [install/stage2-chroot-setup.sh](install/stage2-chroot-setup.sh) inside `arch-chroot` (DKMS modules, initramfs with the patched UFS driver, GRUB, user). Full walkthrough: [install/README.md](install/README.md).
4. After the first boot, add the components you want, each folder has an install section: [gpu/](gpu/README.md), [audio/](audio/README.md), [microphone/](microphone/README.md), [backlight/](backlight/README.md), [kbdlight/](kbdlight/README.md), [lid/](lid/README.md), [hibernate/](hibernate/README.md), [battery/](battery/README.md), [extras/](extras/README.md).
5. **Update the kernel only with [install/books-kernel-update](install/books-kernel-update).** `linux` and `linux-headers` are on `IgnorePkg`. The script checks that the patched UFS module was built for the new kernel and is inside the initramfs before you reboot.

## Repository layout

| Folder | Content |
|---|---|
| [install/](install/README.md) | live stick module, two-stage install scripts, kernel update guard |
| [dkms/](dkms/README.md) | DKMS packages `books-ufs`, `books-eclite`, `books-bt`, `books-i915` and `books-ish.service` |
| [gpu/](gpu/README.md) | render-only i915 notes, Mesa device ID bind mount, VA-API, test tools, the display dead end |
| [audio/](audio/README.md) | speaker amplifier init (`books-amp`) and how it was derived |
| [microphone/](microphone/README.md) | AVS DSP with Windows SST firmware for the DMIC |
| [backlight/](backlight/README.md) | PWM register daemon |
| [kbdlight/](kbdlight/README.md) | keyboard backlight and Fn+F9 |
| [lid/](lid/README.md) | ISH lid sensor to `SW_LID`, suspend drain logger |
| [hibernate/](hibernate/README.md) | swap file, resume offset, lid policy |
| [battery/](battery/README.md) | why the battery is missing on stock kernels, logger, ACPI debugger helper |
| [camera/](camera/README.md) | the failed camera attempt, documented as a negative result |
| [extras/](extras/README.md) | small desktop glue: idle handling, OSD wrappers, mic gain, Sway lines |
| [docs/](docs/) | [ufs.md](docs/ufs.md) (eUFS background and measurements), [power.md](docs/power.md) (power draw, s2idle findings) |

## Component overview

### Internal eUFS

The eUFS hangs off the Intel UFS host controller (`8086:98fa`), not NVMe or AHCI. Upstream has Lakefield support in `ufshcd-pci` since 5.13 plus a link stability fix in 5.15, but on this device the link fails as soon as it switches to HS-G4 Rate B under sustained load (`dme-peer-get PA_GRANULARITY (0x15aa) failed`, `saved_uic_err 0x44`, fallback to PWM-G1 with one lane, hung I/O). Capping the link at HS-G3 makes it stable, at no cost: G4 measured 877 MB/s until it broke, G3 880 MB/s. The patch sets `lkf_max_gear=3` as default. Measurements and history: [docs/ufs.md](docs/ufs.md).

Kernel 7.1 is a trap: commit e72323f3b09f ("Configure only active lanes during link") makes the link startup on Intel `ufshcd-pci` always fail with `-ENOLINK`. 7.2 contains the fix ("Skip link param validation when lanes_per_direction is unset").

### Battery

`\_SB.BAT1` depends (`_DEP`) on `\_SB.ECLT` (`INT3538`, Intel EC-Lite), which depends on the ISH. The stock `intel_ish_ipc` does not know the Lakefield ISH (`98fc`) and `intel_ishtp_eclite` only matches `INTC1035`. With the ID added at runtime and a one-line fallback in eclite, `BAT1` and `ADP1` report live values, and UCSI / USB-C PD comes up as a bonus. Details: [battery/](battery/README.md).

### Bluetooth

The Intel CcP controller (`INT33E4`) sits on a UART and needs serdev support in `hci_intel`. A patch series by Cai Yu (bluez/bluetooth-next PR #821, written for the ThinkPad X1 Fold Gen 1, also Lakefield) adds it. It misses one line: `serdev_device_set_drvdata(serdev, hu)` in `intel_serdev_probe()`. Without it `hci_serdev.c` drops all RX data and init fails with `Reading Intel version information failed (-110)`. Patch 0005 adds it. Details: [dkms/](dkms/README.md).

### GPU

`i915` does not know `9840`. Treating it as Ice Lake for both GT and display freezes the machine (combo PHY / Type-C code that Lakefield does not have). Treating it as **Elkhart Lake, GT only**, with the display left on `simpledrm`, renders correctly: about 35 times the fps of llvmpipe in a GLES2 test, OpenGL 4.6, VA-API decode of H.264, HEVC and VP9 with about a tenth of the CPU time. Runtime PM must stay off for `00:02.0`, otherwise the display freezes when the GPU idles. Details: [gpu/](gpu/README.md).

### Audio and microphone

The codec is a plain Realtek ALC298 on the HDA link (the SoundWire entries in ACPI are unused placeholders from the reference BIOS). The jack works once the controller is bound. The four speaker amps stay in reset until codec coefficient `0x29` is set (2, wait 600 ms, 3, wait 20 ms), which no Linux quirk does. The full init sequence was taken from the Windows driver by emulation. The built-in microphones are PDM DMICs on the audio DSP. They work with the AVS driver, but only with the DSP firmware from the Windows SST package and only if AVS is the first driver that touches the controller after boot. Details: [audio/](audio/README.md), [microphone/](microphone/README.md).

### Backlight, keyboard light, lid

No i915 display means no backlight device. The PWM duty register `BXT_BLC_PWM_DUTY1` (`0xC8258` in BAR0 of `00:02.0`) still works, so a small daemon owns it ([backlight/](backlight/README.md)). The keyboard backlight works through `samsung_galaxybook` once the ISH/EC-Lite path is up, and Fn+F9 arrives on a vendor HID page that the kernel drops ([kbdlight/](kbdlight/README.md)). ACPI `LID0` always says "open". The real lid is an ISH custom sensor (`0x2000E1`) ([lid/](lid/README.md)).

### Touchscreen and input

The touchscreen (`STMD1234:00 06CB:1058`) works out of the box through `hid-multitouch`, Sway lists it as `type: touch`. The one-time message `incomplete report (64/66)` at boot is harmless. Keyboard and touchpad are I2C HID and work. During suspend the I2C HID devices answer the power-save command with a timeout, then resume normally. IRQ 67 (the touchscreen) is what wakes the machine when the lid opens.

### Power

Measured on the device: awake with the screen dark about 2.3 to 2.5 W, idle with screen at 34 % about 2.8 to 3.4 W, normal work 3.5 to 6 W, full load 11 to 12 W (peaks 17 W). **s2idle draws 1.6 to 2.2 W**, so it saves very little. Hibernate draws about 0.1 W. The backlight itself takes about 0.9 W. Details: [docs/power.md](docs/power.md).

### Camera (negative result)

The IPU (`9830`) is not supported by `intel-ipu6`. A patched driver with the Jasper Lake profile gets the firmware through the CSE (`FW_SETUP_DONE`, no `AUTH_FAILED`), but the IPU bootloader then reports `0xffffffeb` (-21). The genuine Lakefield IPU firmware from the Windows driver package fails the same way. Even past that point, a clock driver (`INT346F`), a sensor driver for `HYV1A11` and a libcamera pipeline would be missing. Everything found is in [camera/](camera/README.md) in case someone picks it up.

## Emergency notes

- **GPU trouble:** in the GRUB menu press `e`, append `module_blacklist=i915` to the `linux` line, boot with Ctrl+X. You are back to `simpledrm` + Pixman.
- **Boot debugging:** the default is `loglevel=3`, so kernel messages do not garble the tty1 login. For debugging, add `loglevel=7` the same way.
- **System does not boot after a kernel update:** boot the live stick (it brings its own G3 module), mount the root partition of the eUFS, `arch-chroot`, then `dkms install books-ufs/1.0 -k <version>` and `mkinitcpio -P`.
- **Clock jumped to 2020:** after the battery has run completely flat, the RTC loses the time and starts in 2020. TLS then fails (certificates "not yet valid"). Enable NTP: `sudo timedatectl set-ntp true && sudo systemctl enable --now systemd-timesyncd`. Without network: `sudo date -s "YYYY-MM-DD HH:MM" && sudo hwclock --systohc`.
- **Harmless:** ACPI BIOS error `AE_ALREADY_EXISTS` (`XHC.RHUB`) at boot is a firmware bug. After resume from hibernate, `ucsi_acpi ... failed to re-enable notifications (-110)` appears once.
- **Known open issue:** a shutdown hang with `hci_uart` was seen once, and `modprobe -r hci_uart` hung once. Not investigated.

## Legal notes

- **No vendor binaries.** This repository contains no Microsoft, Intel, Realtek or Samsung firmware or driver files. Where a component needs them (DSP firmware for the microphone, IPU firmware for the camera experiment, the Realtek driver for the analysis), the README of that folder explains where to download the package (Microsoft Update Catalog) and how to extract the file yourself.
- **Derived data.** [audio/books-amp-c18b.seq](audio/books-amp-c18b.seq) is a list of amplifier register writes. It was obtained by analysing and emulating the Windows Realtek driver, for the sole purpose of making the hardware work under Linux (interoperability). It contains no driver code.
- **Upstream patches.** The Bluetooth series 0001-0004 is by Cai Yu and keeps its original authorship and `Signed-off-by` lines.

## License

- Kernel patches are derived from the Linux kernel and are licensed **GPL-2.0-only**, like the kernel.
- All scripts, services and configuration files in this repository are licensed **GPL-2.0-only** as well.
- Full text: [LICENSE](LICENSE).

## Disclaimer

This is provided as is, **without any warranty**, see sections 11 and 12 of the [LICENSE](LICENSE).

- This laptop boots from eUFS, and the eUFS needs a patched kernel module. A broken patch, a failed DKMS build or a kernel update done the normal way can leave you with an unbootable system. Always use `books-kernel-update`, and **keep a live stick** that can mount the eUFS (see [install/](install/README.md)).
- Several tools here write directly to hardware registers (GPU PWM, codec coefficients, I2C amplifiers) or load modified drivers. They were tested on one unit only. Different BIOS versions or hardware revisions may behave differently.
- The research scripts in `gpu/`, `camera/` and `microphone/` can hang the machine. They contain a dead-man switch that hard-reboots via SysRq after 300 s unless you confirm. Save your work before running them.
- Installing Linux this way wipes Windows from the eUFS. There is no Samsung recovery medium to download. Make a full image of the eUFS first if you might want Windows back.

## Credits

- Cai Yu, for the `hci_intel` CcP/serdev series (bluez/bluetooth-next PR #821).
- Adrian Hunter and Intel, for the Lakefield support in `ufshcd-pci`.
- The authors of the AVS driver and the Lakefield AVS work in the kernel and linux-firmware.
- The maintainers of `samsung_galaxybook`, `intel_ishtp_eclite`, `hid-sensor-custom`, `i915`, Mesa and intel-media-driver.
- The [faelprogramer/galaxybook-linux-fixes](https://github.com/faelprogramer/galaxybook-linux-fixes) project, for collecting fixes for the same model.
- Everyone who reported their attempts with this laptop on forums. Every half-answer helped narrow things down.

Issues and pull requests with results from other units (different BIOS, 512 GB eUFS, other kernels) are very welcome.
