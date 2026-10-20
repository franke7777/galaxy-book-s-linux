# Battery

## Why stock kernels show no battery

Only `ADP1` appears, no `BAT0`/`BAT1`. In the DSDT, `\_SB.BAT1` (PNP0C0A) has `_DEP` on `\_SB.ECLT` (`INT3538`, Intel EC-Lite), which has `_DEP` on the ISH (`8086:98fc`). The battery values live in the vendor operation regions `0x9E`/`0x9F` and are only valid when `ECLT.ELRD == 0xAA`. Without an ISH driver `ELRD` stays 0 and `BAT1` is never enumerated.

`_BIX`/`_BST` have a fallback: values from the SMI call `\GSSM 0xF0` (0/1), cached in `BAT1._INI`. Read through the ACPI debugger they look plausible (design 36.5 Wh, full 35.0 Wh, 8.665 V), but they are **frozen**: unchanged after more than 7 minutes on battery, and `PWRS`/`ADP1` stay 0 with the charger connected. So that path is useless.

The fix is the ISH ID plus `INT3538` in eclite, see [../dkms/](../dkms/README.md) (`books-eclite`, `books-ish.service`).

## Tools

- [books-batlog](books-batlog) + [books-batlog.service](books-batlog.service) + [books-batlog.timer](books-batlog.timer): one CSV line every 5 minutes to `/var/log/books-battery.csv` (time, status, %, Wh, W, brightness, load, Wi-Fi state; interface via `WLAN_IF`, default `wlp1s0`). Install the script to `/usr/local/bin`, the units to `/etc/systemd/system`, enable the timer.
- [acpidbg-eval.py](acpidbg-eval.py): run commands through the kernel ACPI debugger (`/sys/kernel/debug/acpi/acpidbg`, needs debugfs and Secure Boot off). Used to evaluate `_BST`, `_BIX` and `_BCM` during the investigation.

Measurements from these logs: [../docs/power.md](../docs/power.md).
