# Built-in microphone (DMIC on the audio DSP)

**Status:** works, through the AVS driver with the DSP firmware from the Windows Intel SST package. Tested for speech recognition in a browser and for recordings. Built-in mic, speakers and headphone jack all run under AVS at the same time. Not tested: the mic jack.

## Starting point

- The ALC298 codec only has speaker (`0x17`), headphone (`0x21`) and the mic jack (`0x18`). No internal microphone is connected to the codec.
- The built-in microphones are **PDM DMICs on the audio DSP**. The NHLT describes a DMIC endpoint with subsystem `144dc18b`. Without running DSP firmware they are unreachable.
- With `snd_hda_intel` (`dsp_driver=1`) the DSP is not used, so no microphone.
- **AVS** (`snd_soc_avs`) officially knows Lakefield (`lkf_desc` = TGL ops, IMR, minimum firmware 10.28.0.5646). **SOF** does not know `98c8`.
- The topologies `intel/avs/dmic-tplg.bin` and `hda-*-tplg.bin` are in linux-firmware.

## Firmware candidates

| File | Version / date | Signing key (SHA-256 of modulus, shortened) |
|---|---|---|
| linux-firmware `intel/avs/lkf/dsp_basefw.bin` | 10.28.0.12823 / 2026-06-12 | 6eab243077483b41 |
| Windows SST 10.28.0.3855 (Microsoft Update Catalog, update ID starting `7c535010-`), `Fw/dsp_fw_release.bin` | 10.28.0.3732 / 2020-03-19 | 6eab243077483b41 |
| Windows SST 10.28.0.9174 (update ID starting `d60d33e7-`), `Fw/dsp_fw_release.bin` | 10.28.0.7068 / 2022-01-19 | 6eab243077483b41 |

All three have the same format (`$AE1` then `$CPD` "ADSP" then `ADSP.man` with extensions 15 and 22, then cavs0015) and the same Intel RSA-2048 key. The packages are generic for Lakefield (`98c8`); there is no Samsung-specific variant. Tools to inspect them: [css.py](css.py) (CSS/`$MN2` header, version, date, key hash) and [am1.py](am1.py) (`$AM1` module header and `$CPD` entries).

**The one that works: Windows SST 10.28.0.9174 (FW 10.28.0.7068).** The linux-firmware file 10.28.0.12823 is rejected by the CSE (`lec 0x2c`, see below).

## Getting the firmware (not included here)

1. Microsoft Update Catalog (catalog.update.microsoft.com): look for the Intel Smart Sound Technology (SST) driver for Lakefield, version **10.28.0.9174**, for example by searching for the hardware ID `VEN_8086&DEV_98C8`. Its update ID starts with `d60d33e7-`.
2. Download the `.cab` and extract it: `mkdir sst && cabextract -d sst <file>.cab` (or `7z x -osst <file>.cab`). Nested `.cab` files may need a second round.
3. The file you need is `Fw/dsp_fw_release.bin`. Check it with `python3 css.py sst/Fw/dsp_fw_release.bin`: version 10.28.0.7068, key `6eab243077483b41`.
4. Install it where it takes precedence over linux-firmware and survives package updates:
   ```
   sudo install -Dm644 sst/Fw/dsp_fw_release.bin /lib/firmware/updates/intel/avs/lkf/dsp_basefw.bin
   ```

## Setup

1. Firmware as above.
2. [../audio/books-audio.conf](../audio/books-audio.conf) to `/etc/modprobe.d/`: only `options snd_intel_dspcfg dsp_driver=4`.
3. `books-hda.service` disabled (it binds `snd_hda_intel`, pointless under AVS).
4. [../audio/books-amp.service](../audio/books-amp.service) for the speakers (waits for the ALC298 card; under AVS the codec node is `hwC1D0`, the script finds it).
5. Reboot. Expected cards: `AVS HD-Audio` (codec ALC298), `AVS DMIC`, `AVS PROBE`, and no "firmware boot failed" in `journalctl -k -b | grep snd_soc_avs`.
6. **The topology control `DMIC Volume` (peakvol, Q1.31) starts at 0**, so `AVS DMIC` delivers only zeros. Set it to 0 dB and store it:
   ```
   amixer -c DMIC cset numid=1 2147483647
   sudo alsactl store
   ```
7. The level is low (speech from close range about -18 dBFS peak / -36 dBFS RMS, channel 0 more sensitive than channel 1). Raise the PipeWire source volume to 2.0 (+18 dB): `wpctl set-volume -l 3.0 <id> 2.0`. The node name changes between boots (`alsa_input.platform-avs_dmic.3...`, `.5...`), so WirePlumber does not reliably remember it; [../extras/books-mic-gain](../extras/books-mic-gain) finds the node by prefix and sets the gain at session start.

NHLT DMIC (endpoint 5, subsystem `144dc18b`): 2ch/48k/16-in-16 and 2ch/48k/24-in-32, each with a 3072-byte blob. `dmic-tplg.bin` has variants for 2/4 channels, 16/32 bit, 48/16 kHz. 2ch/48k/16 matches; the many "Endpoint format configuration not found" messages come from the other variants and are harmless.

**Way back** to plain HDA: `dsp_driver=1` plus `options snd_hda_intel position_fix=1 power_save=0`, `systemctl enable books-hda`, reboot.

## How it was found (DSP boot states)

ROM status register FSR: bits 0 to 23 state, 24 to 27 module, bit 31 error.

- **linux-firmware, AVS loaded at boot:** `transfer fw failed: -110, status 0x80000012, lec 0x2c` = `CSE_VALIDATE_IMAGE_REQUEST` + error 44 **`CSE_VALIDATION_FAILED`**: the security engine rejects the image.
- **Switching from snd_hda_intel to AVS at runtime** ([avs-on.sh](avs-on.sh) / [avs-off.sh](avs-off.sh), firmware via `firmware_class.path`): Windows 3732 (with `ignore_fw_version=1`) and Windows 7068 end with `status 0x00000003, lec 0` = FW_MANIFEST_LOADED, no error, but timeout.
- **Debug AVS with ROM state logging** ([avs-loader-rom-trace.patch](avs-loader-rom-trace.patch) for `sound/soc/intel/avs/loader.c`, [avs-dbg.sh](avs-dbg.sh)), Windows 7068: `0x06000021` (t=0) then `0x01000010` CSE_IMR_REQUEST (t=9 ms, DMA 32768) then `0x00000003` (t=72 ms), then stuck for 30 s. **The DMA stops at 32768 bytes**, the ROM fetches no more data. Reproducible on a fresh boot (`0x01000010` at 7 ms, `0x00000003` at 67 ms).
- Same debug AVS with linux-firmware 12823 after a runtime switch: the same 32 KB stall, no `0x2c`. Conclusion: the 32 KB stall happens because `snd_hda_intel` (and books-amp) used the controller before. It is an artefact of switching drivers, not a statement about the firmware. Also, after a failed load in the same boot the CSE seems to stay stuck, so only one load attempt per boot is meaningful ([avs-boottest.sh](avs-boottest.sh) does exactly one).
- **Breakthrough: AVS first.** One boot with `dsp_driver=4` and the Windows 7068 firmware (for a single test boot: `snd_intel_dspcfg.dsp_driver=4 snd_soc_avs.ignore_fw_version=1 firmware_class.path=<dir>` appended to the GRUB `linux` line): no "firmware boot failed", three cards. A fresh controller plus the Windows firmware boots. The linux-firmware 12823 file is still rejected by the CSE in this situation (`lec 0x2c`).

The way back to `snd_hda_intel` (`avs-off.sh` + restart PipeWire) worked every time during these tests.

## Noise filter: tried, turned off again

A PipeWire `libpipewire-module-echo-cancel` with `aec/libspa-aec-webrtc` (`monitor.mode = true`, one channel, `noise_suppression` + `high_pass_filter` on) reduced noise in silence from RMS about 930 to about 90 (-20 dB). **But speech recognition got clearly worse** with the filter. Unfiltered at gain 2.0 is better. With `gain_control` and `voice_detection` on, the filtered output was almost all zeros (the AGC wants an analog mic control that does not exist here). If noise bothers you, lower the gain rather than filter, or create a filtered source only for calls.

## Tools in this folder

| File | Purpose |
|---|---|
| [avs-on.sh](avs-on.sh), [avs-off.sh](avs-off.sh) | switch between `snd_hda_intel` and AVS at runtime (research only) |
| [avs-dbg.sh](avs-dbg.sh), [avs-boottest.sh](avs-boottest.sh) | load the debug AVS module (path in `AVS_KO`) and log ROM states, one attempt per boot |
| [avs-loader-rom-trace.patch](avs-loader-rom-trace.patch) | debug patch for `loader.c`: logs every FSR change, waits up to 30 s |
| [css.py](css.py), [am1.py](am1.py) | firmware header inspection |
