# Display brightness without i915 display support

Because the panel stays on `simpledrm` (see [../gpu/](../gpu/README.md)), there is no kernel backlight device and `brightnessctl` has nothing to control. The GPU PWM block still works when written directly:

| Register (BAR0 of `00:02.0`) | Name | Use |
|---|---|---|
| `0xC8250` | `BXT_BLC_PWM_CTL1` | PWM control (left as set by the firmware) |
| `0xC8254` | `BXT_BLC_PWM_FREQ1` | period, read once at start |
| `0xC8258` | `BXT_BLC_PWM_DUTY1` | duty cycle = brightness |

Counter-checks on the panel: duty 10 % is visibly darker, PWM off is dark, `PP_CONTROL` bit 2 (backlight enable) off is dark.

## books-backlightd

[books-backlightd](books-backlightd) maps BAR0 through `/sys/bus/pci/devices/0000:00:02.0/resource0`, owns the duty register and glides to the target at 60 fps (easing). The curve is quadratic (level p % gives duty (p/100)^2), minimum 15 % (3 % was practically black). The level is saved to `/var/lib/books-backlight/level` one second after the last change and restored at boot.

Commands go through the FIFO `/run/books-backlight/ctl` (writable by group `wheel`, override with `BOOKS_GROUP`), so no sudo is needed:

```
books-backlight          # print the target level
books-backlight 40       # set
books-backlight +2 / -2  # step
books-backlight watch    # print every change (for a status bar)
```

The current level is in `/run/books-backlight/level`. The `watch` mode polls every 100 ms instead of using signals: a real-time signal sent to waybar while it was restarting killed the bar.

Lesson from the first version: running a sudo Python script per key press, each doing its own fade, piled up while scrolling and display and indicator drifted apart. Hence one daemon.

[books-backlight.sleep](books-backlight.sleep) sets duty 0 before suspend directly on the register and restores the exact value after resume. Brightness stays the same after resume, the picture is back immediately.

## Install

```
sudo install -m755 backlight/books-backlightd backlight/books-backlight /usr/local/bin/
sudo install -m644 backlight/books-backlight.service /etc/systemd/system/
sudo install -m755 backlight/books-backlight.sleep /usr/lib/systemd/system-sleep/books-backlight
sudo systemctl enable --now books-backlight.service
```

Key bindings and an OSD wrapper: [../extras/](../extras/README.md).

## Dead ends

- ACPI `_BCM` needs i915 (ASLE / IGD OpRegion). `acpi_backlight=video` only gives a control without effect.
- eDP AUX / DPCD backlight does not come up without i915: the AUX-A power well (`0x45444`) never acknowledges, also not with `ICL_PORT_CL_DW12` lane enable, AUX times out.
- The VBT sits in the OpRegion (ASLS in ACPI NVS), `/dev/mem` refuses to read it, there is no PCI ROM.
