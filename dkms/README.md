# DKMS packages

Each package downloads the matching driver source for the target kernel from kernel.org at build time (`prebuild.sh` + `kfetch.sh`), applies its patch and builds one module into `updates/dkms/`. So the packages follow kernel updates without shipping kernel source. A build needs network access.

| Package | Module | What it fixes | Build time on the device |
|---|---|---|---|
| `books-ufs` | `ufshcd-pci` | eUFS link capped at HS-G3 (vital, root lives there) | seconds |
| `books-eclite` | `intel_ishtp_eclite` | battery: accept ACPI `INT3538` | seconds |
| `books-bt` | `hci_uart` | Bluetooth: serdev support for the Intel CcP in `hci_intel` | about a minute |
| `books-i915` | `i915` | GPU as render-only device (optional, see [../gpu/](../gpu/README.md)) | about 3.5 minutes |

Plus [books-ish.service](books-ish.service), which binds the ISH and loads eclite.

## Install

```
for p in books-ufs books-eclite books-bt books-i915; do
  sudo cp -r dkms/$p /usr/src/$p-1.0
  sudo dkms install $p/1.0
done
sudo install -m644 dkms/books-ish.service /etc/systemd/system/
sudo systemctl enable --now books-ish.service
```

For `books-ufs`, the initramfs must contain the patched module: `MODULES=(ufshcd_core ufshcd_pci)` in `/etc/mkinitcpio.conf`, then `sudo mkinitcpio -P` and check with `sudo lsinitcpio /boot/initramfs-linux.img | grep updates/dkms/ufshcd-pci`. [../install/stage2-chroot-setup.sh](../install/stage2-chroot-setup.sh) does all of this for the first three packages.

`kfetch.sh` is duplicated into every package directory because DKMS only copies the package directory into its build tree.

## books-ufs

[books-ufs/ufs-lkf-g3.patch](books-ufs/ufs-lkf-g3.patch) adds the parameter `lkf_max_gear` (default 3) to `ufs_intel_lkf_pwr_change_notify()`. Background and measurements: [../docs/ufs.md](../docs/ufs.md). Check after boot: `cat /sys/module/ufshcd_pci/parameters/lkf_max_gear` shows 3, `modinfo -n ufshcd_pci` points to `updates/dkms`.

## books-eclite and books-ish.service (battery)

In the DSDT, `\_SB.BAT1` (PNP0C0A, `_STA` 0x1F) has `_DEP` on `\_SB.ECLT` = `INT3538` "Intel EC-Lite", which has `_DEP` on the ISH (`\_SB.PCI0.ISHD`, PCI `8086:98fc`). The battery data lives in the vendor operation regions `0x9E`/`0x9F` of `ECLT` and is only valid when `ECLT.ELRD == 0xAA`. `intel_ishtp_eclite` already handles exactly these regions, two things are missing:

1. `intel_ish_ipc` does not know the Lakefield ISH. `books-ish.service` adds the ID at runtime: `echo 8086 98fc > /sys/bus/pci/drivers/intel_ish_ipc/new_id`. The ISH firmware then comes up (it is ROM loaded on this machine), the sensor hub HID and the EC-Lite ISHTP client appear.
2. `intel_ishtp_eclite` only looks for `INTC1035` (Elkhart Lake). [books-eclite/eclite-INT3538.patch](books-eclite/eclite-INT3538.patch) adds `INT3538` as a fallback.

Result: `BAT1` with live values (charging/discharging, capacity, power, voltage), `ADP1` correct, and as a bonus UCSI / USB-C power delivery (15 V / 4.8 A detected). The `_DSM` UUID in `ECLT` (`91d936a7-1f01-49c6-a6b4-72f00ad8d8a5`) matches the driver. More in [../battery/](../battery/README.md).

## books-bt (Bluetooth)

- `0001-0004-caiyu-hci_intel-ccp-serdev.patch`: series by Cai Yu (bluez/bluetooth-next PR #821, patches 15 to 18 of that series, written for the ThinkPad X1 Fold Gen 1, also Lakefield / `INT33E4`). Kept unchanged with the original authorship.
- `0005-hci_intel-serdev-set-drvdata.patch`: the series misses `serdev_device_set_drvdata(serdev, hu)` in `intel_serdev_probe()`. Without it `hci_serdev.c` drops all RX data (WARN in `hci_uart_receive_buf` / `hci_uart_write_wakeup`) and init fails with `Reading Intel version information failed (-110)`.

`prebuild.sh` fetches all of `drivers/bluetooth` for the kernel version, applies the five patches and builds only `hci_uart`. The module loads automatically through the ACPI alias `INT33E4`. Result: firmware `intel/ibt-20-1-3.sfi` loads, the speed changes to 921600, `hci0` is up, scanning finds devices. The series applies to 7.2.9 with offsets and is not upstream in 7.2.

Open: `modprobe -r hci_uart` hung once, and a reboot hung once on shutdown. Not investigated.

## books-i915

See [../gpu/README.md](../gpu/README.md). `prebuild.sh` downloads the full kernel tarball for the version (cached in `/var/cache/books-i915`, about 160 MB, override with `BOOKS_I915_CACHE`), extracts `drivers/gpu/drm/i915` plus `intel_ips.h`, applies [books-i915/i915-lkf.patch](books-i915/i915-lkf.patch) and makes the tracepoint include paths absolute for the out-of-tree build.
