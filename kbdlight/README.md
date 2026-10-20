# Keyboard backlight and Fn+F9

## Backlight

The keyboard backlight works with the stock `samsung_galaxybook` driver, levels 0 to 3 (`/sys/class/leds/samsung-galaxybook::kbd_backlight`). The firmware forwards `SASB 0x78` as EC command `0xFC` (read) / `0xFD` (set) through `ECLT` to the ISH, so it only works once the ISH and EC-Lite path is up ([../dkms/](../dkms/README.md)). The light is faint; test in a dark room.

At boot the driver loads before the EC path is ready (`CSFI` returns `0xff`) and creates no LED. [books-kbdlight.service](books-kbdlight.service) runs after `books-ish`, reloads the module until the LED exists, gives group `wheel` (override with `BOOKS_GROUP`) write access and restores the last level (`/var/lib/books-kbdlight/level`, saved on shutdown).

```
books-kbdlight        # next level 0 -> 1 -> 2 -> 3 -> 0
books-kbdlight 0..3   # set level
```

## Fn+F9

Fn+F9 produces no evdev event. The keyboard (`SLHD0001`, ENE `0CF2:9028`, I2C bus 3) sends it as **report 5 on the vendor page `0xFF7F`**, 9 bytes, key code **`0xBF`**, one report per press and none on release. The kernel drops it. [books-fnkeysd](books-fnkeysd) reads the hidraw node and emits `KEY_KBDILLUMTOGGLE` through uinput ("Book S Fn Keys"), which Sway sees as `XF86KbdLightOnOff`. Bind Super+F9 too as a fallback.

## Install

```
sudo install -m755 kbdlight/books-kbdlight kbdlight/books-fnkeysd /usr/local/bin/
sudo install -m644 kbdlight/books-kbdlight.service kbdlight/books-fnkeys.service /etc/systemd/system/
sudo systemctl enable --now books-kbdlight.service books-fnkeys.service
```

Sway lines and an OSD wrapper: [../extras/](../extras/README.md).

Notes: Samsung says the backlight follows the ambient light sensor on Windows, but the ISH exposes no light sensor here (only the custom lid sensor `0x2000E1`). `SASB 0x7A` is a generic EC pass-through and was not touched.
