# Lid switch

ACPI `LID0` always reports "open", so Linux never sees the lid (only the panel turns off through its magnetic sensor, the system keeps running). The real lid is the ISH sensor **"Lid Closed Detection Sensor"**, HID sensor usage `0x2000E1`, handled by `hid-sensor-custom` and disabled by default (`enable_sensor 0`).

Data stream `/dev/HID-SENSOR-2000e1.*`: 16 byte header (usage u32, timestamp u64, length u32) plus 29 bytes, **byte 26 = 1 closed / 0 open**.

[books-lidd](books-lidd) enables the sensor (writing 1 while enabled gives EINVAL, so it writes 1/0/1), mirrors it to a virtual switch (uinput `SW_LID`, "Book S Lid Switch") and re-enables the sensor if it stays silent after resume. logind handles it like a normal lid (`HandleLidSwitch`, inhibitors).

Result: lid closed = s2idle, lid open = awake, picture back immediately, video keeps playing. The wake IRQ when opening is the touchscreen (IRQ 67), not the lid sensor. For the battery side of suspend see [../docs/power.md](../docs/power.md) and [../hibernate/](../hibernate/README.md).

## Install

Requires `books-ish.service` ([../dkms/](../dkms/README.md)).

```
sudo install -m755 lid/books-lidd /usr/local/bin/
sudo install -m644 lid/books-lid.service /etc/systemd/system/
sudo systemctl enable --now books-lid.service
# optional: log battery before/after each suspend to /var/log/books-sleep.log
sudo install -m755 lid/books-sleeplog.sleep /usr/lib/systemd/system-sleep/books-sleeplog
```
