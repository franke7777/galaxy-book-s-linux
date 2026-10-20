# Power draw, suspend and wake findings

All numbers measured on the test device with the battery driver from [../battery/](../battery/README.md) (`power_now`, `energy_now`, upower history and the logs of `books-batlog` and `books-sleeplog`). Battery: design 36.5 Wh, full 35.0 Wh. The eclite energy resolution is only about 0.34 Wh, so short measurements are rough.

## Typical draw

| State | Draw |
|---|---|
| Awake, screen dark (backlight 15 % + output off) | 2.3 to 2.5 W |
| Awake, lid closed (screen off) | about 2.6 W |
| Idle, screen at 34 % | 2.8 to 3.4 W |
| Normal work (browser, terminal) | 3.5 to 6 W |
| Full load | 11 to 12 W, peaks 17 W |
| **s2idle** | **1.6 to 2.2 W** |
| Hibernate | about 0.1 W |
| Backlight alone (duty 3136 against 0) | about 0.9 W |

Example: unplugged in the morning, 6 hours awake with the lid open and the screen on: 79 % to 24 %.

## s2idle saves almost nothing

Suspend works (lid closed = s2idle, lid open = awake, picture back immediately, see [../lid/](../lid/README.md)). But:

- Long measurement: 2.16 h in s2idle, 11.29 to 6.50 Wh = **about 2.2 W**, about 6.5 % per hour, roughly 15 hours from full to empty. Another run: 5.4 h, 84 % to 47 % (28.7 to 16.1 Wh), about 2.3 W.
- With dyndbg on `drivers/pci/pci-driver.c` and `drivers/acpi/x86/s2idle.c` during suspend: all PCI devices go to D3hot (also i915, UFS, Wi-Fi), only the ISH stays in D0 (expected, it provides the lid and wake). LPS0 entry/exit works, no spurious wakeups. The only wake IRQ is 67 (touchscreen `STMD1234`) when the lid opens.
- The CPU cores use `C3_ACPI` = MWAIT `0x60` via `acpi_idle`, because `intel_idle` does not know Lakefield.
- `intel_pmc_core` does not know Lakefield either (no debugfs), `low_power_idle_system_residency_us` stays 0. There is no way to see whether S0ix is reached. The draw says it is not.
- UFS is not the culprit: `spm_lvl` = 5 (device power down + link off).
- Turning the backlight PWM off before suspend ([../backlight/books-backlight.sleep](../backlight/books-backlight.sleep)) changed nothing measurable; the GPU in D3hot probably stops the PWM anyway. The hook stays, it does no harm.
- The kernel side is clean: `pm_test=devices` dry run and real s2idle without hangs, resume of all devices about 0.45 s.
- Remaining candidates for the drain: the ISH staying in D0, the display pipe without an i915 display driver. A comparison with Windows Modern Standby was not done.

## No wake timer

`rtc0` is `acpi-tad` with `caps 0x04` (clock only), there is no CMOS RTC. So no `rtcwake`, and no suspend-then-hibernate by timer. logind reports `CanSuspendThenHibernate = na`. The battery alarm (10 %) does not wake the machine from s2idle either: a night in s2idle starting at 45 % ended with an empty battery.

Consequence, see [../hibernate/](../hibernate/README.md): on battery, a closed lid keeps the machine awake (about 2.6 W, so 20 minutes cost about 1 Wh), locked and with the keyboard light off, and after 20 minutes it hibernates. On AC, a closed lid means s2idle. Idle on battery (screen off at 5 min, lock at 10 min, hibernate at 20 min) is handled by [../extras/books-idle](../extras/books-idle). UPower `CriticalPowerAction=Auto` hibernates at 2 %.

## RTC after a flat battery

When the battery runs completely flat, the RTC loses the time and the system starts in 2020. TLS then fails with "certificate not yet valid". Keep `systemd-timesyncd` enabled; it also saves `/var/lib/systemd/timesync/clock`, so after a flat battery the clock jumps at least to the last sync time at boot, and to the right time once Wi-Fi is up.

## Logging tools

- [../battery/books-batlog](../battery/books-batlog) + timer: one CSV line every 5 minutes in `/var/log/books-battery.csv` (status, %, Wh, W, brightness, load, Wi-Fi), no resident process.
- [../lid/books-sleeplog.sleep](../lid/books-sleeplog.sleep): battery before and after every suspend in `/var/log/books-sleep.log`. Right after resume eclite still reports the old value, so the "after" value is read 60 s later through a transient timer unit (systemd kills background processes started from sleep hooks).
