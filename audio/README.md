# Audio: speakers and headphone jack

## Hardware

- The codec is a classic **Realtek ALC298 on the HDA link** (subsystem `144d:c18b`), not SoundWire. The `SWD0` to `SWD7` entries in ACPI are placeholders from Intel's reference BIOS (eight times RT700, none active). Stock kernels fail on them (`_DSD` endpoints return a Buffer instead of a Package) and end up with no sound card.
- Codec pins: speaker `0x17`, headphone `0x21`, mic jack `0x18`. The built-in microphones are not on the codec, see [../microphone/](../microphone/README.md).
- Four speaker amplifiers on I2C addresses **`0x3c`, `0x38`, `0x3d`, `0x39`**, reachable only through an I2C bridge inside the codec (vendor coefficients on NID `0x20`): `0x22` address, `0x23` register, `0x24` value high, `0x25` value low, `0x26` start. Start = `0xb011` for 1-byte values, **`0xb017` for 3-byte values** (filter coefficients). The bridge only reports "done" (`0xb001`), no ACK and no read data, so you cannot probe which address answers.

## Binding the controller

The controller `8086:98c8` is not in `snd_hda_intel`'s ID table. Two ways:

- **AVS** (recommended, needed for the microphone): `options snd_intel_dspcfg dsp_driver=4`, see [../microphone/](../microphone/README.md). The ALC298 then appears on the card "AVS HD-Audio".
- **Plain HDA** (no microphone, no Windows firmware needed): `options snd_intel_dspcfg dsp_driver=1` and `options snd_hda_intel position_fix=1 power_save=0`, plus [books-hda.service](books-hda.service), which adds the ID at runtime with driver_data `0x46202403` (`AZX_DRIVER_SKL | AZX_DCAPS_INTEL_SKYLAKE`, kernel 7.2). **`position_fix=1` (LPIB) is required**: without it the stream runs formally (`hw_ptr` counts, "Too big adjustment 256"), but no sound comes out.

The headphone jack works with either. The speakers additionally need the amplifier init below.

## Why the speakers stay silent

The amplifiers are held in reset as long as the lower 2 bits of codec coefficient **`0x29`** are 0. The Windows driver sets `0x29` to 2, waits 600 ms, sets it to 3, waits 20 ms. Only then do the amplifiers respond. No Linux quirk does this, so all of these stayed silent with a running stream:

- the quirks `alc298-samsung-amp`, `alc298-samsung-amp-v2-2-amps`, `alc298-samsung-amp-v2-4-amps`
- the gen 1 and gen 2 sequences sent to **every** I2C address `0x08` to `0x77` ([samsung-amp-probe.py](samsung-amp-probe.py)), all codec GPIOs high, pin `0x14` (unused output with EAPD) enabled
- the gen 2 tables found in the Windows driver, sent to `0x38/0x39/0x3c/0x3d` and to all addresses ([samsung-amp-win.py](samsung-amp-win.py))

(An earlier guess "different amplifier chip" was wrong: they are the same gen 2 amplifiers, they were just held in reset.)

## How the sequence was derived

For interoperability, the init sequence was taken from the behaviour of the Windows driver, not from a hardware trace:

1. Realtek audio driver **6.0.9689.1** from the Microsoft Update Catalog, search term `VEN_10EC&DEV_0298&SUBSYS_144DC18B`. Extract the `.cab` (`cabextract` or `7z x`). The INF `HDXSSTSamsung.inf` lists C18B with an **empty** EQ section; effects run on the SST DSP (`ForceSST=1`, `SSTPPCfg\...\SPK\EFX`).
2. In `RTKVHD64.sys` (disassembled with objdump): starting at file offset `0x1c3628` are the gen 2 amplifier tables, four of them (L/R with `23ba:94`, L/R with `23ba:8d`). Differences to Linux: a reset `2000:1` + 10 ms first, at the end `23b9:0 23e0:20 23e1:1`, plus biquad filters `0x2100` to `0x22dc`. C18B sits in the subsystem lists next to C18A (Galaxy Book Ion, gen 1 in Linux).
3. The subsystem switch at `0x1403f5898` sets the flag `[+0x460]` for c18b instead of `[+0x444]` (gen 1, c18a). That flag calls the init routine **`0x14041a1c4`**; on/off is **`0x14041eccc`**.
4. Both routines were executed in the Unicorn emulator with [rtk-emu.py](rtk-emu.py), which hooks the driver's coefficient write, amplifier write and sleep helpers and logs all calls. Result: the `0x29` dance and **612 amplifier writes** (init with `2014=0xb`, `2042/2043`, `24ff`, `23ba=0x9a`, `23e0=0x39`, `23e1=1` and others, plus 24-bit biquad filter coefficients `0x2100` to `0x22dc`), then "on" = `203a=0x81`, `23ff=1` for each amplifier.

The resulting write list is [books-amp-c18b.seq](books-amp-c18b.seq). It is data (register, value pairs), no driver code. The driver itself is not part of this repository; `rtk-emu.py` contains the function addresses for version 6.0.9689.1 only.

## books-amp

[books-amp-c18b.py](books-amp-c18b.py) replays the `.seq` file through the codec hwdep node (`/dev/snd/hwC?D0` of the card with the ALC298, found automatically, works with snd_hda_intel and AVS). It talks to the codec directly with `ioctl(HDA_IOCTL_VERB_WRITE = 0xC0084811)` instead of spawning `hda-verb` per command: the first version started about 6000 processes per init and took 10 to 14 s. Now the full init takes about 1.5 s (0.6 s of it is the pause from the Windows sequence), about 2 s under AVS.

```
sudo books-amp        # init + on
sudo books-amp off
sudo books-amp init | on
```

### Install

```
sudo install -Dm755 audio/books-amp-c18b.py /usr/local/lib/books-amp/books-amp-c18b.py
sudo install -m644 audio/books-amp-c18b.seq /usr/local/lib/books-amp/books-amp-c18b.seq
sudo ln -sf /usr/local/lib/books-amp/books-amp-c18b.py /usr/local/bin/books-amp
sudo install -m644 audio/books-amp.service /etc/systemd/system/
sudo install -m755 audio/books-amp.sleep /usr/lib/systemd/system-sleep/books-amp
sudo install -m644 audio/books-audio.conf /etc/modprobe.d/books-audio.conf
sudo systemctl enable books-amp.service
```

Also install `pipewire-pulse`, `pipewire-alsa`, `alsa-utils`. Do **not** set `model=alc298-samsung-amp`: it writes gen 1 sequences to `0x3a/0x39`, where nothing answers.

The sleep hook only triggers `systemctl --no-block restart books-amp` after resume. A hook that waits keeps `user.slice` frozen, which showed up as a 10 s frozen picture after opening the lid. With the hook and the ioctl version, sound is back almost immediately after resume. The service waits for the ALC298 card and does not block the login.

## Testing pitfalls

- `speaker-test -D pulse` silently aborts here (no ALSA pulse plugin). Use `-D default` or `plughw:0,0`.
- "Master" is a virtual control that is subtracted from "Headphone" (Headphone 76 + Master 57 is effectively -60 dB).

## NHLT note

Besides the DMIC endpoint (PDM, subsystem `144dc18b`), the NHLT also describes I2S outputs on SSP0 and SSP3 (generic, subsystem 1, probably the Intel reference). The speakers are not on them; they work through the codec as described above.
