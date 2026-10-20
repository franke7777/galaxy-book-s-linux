# Camera: negative result

**Status: does not work, attempt stopped.** Even with the matching Lakefield IPU firmware from the Windows driver, the IPU bootloader rejects it with -21. Use a USB webcam. This folder documents everything found so far, so the next person does not have to start from zero.

## Hardware

- **Sensor:** ACPI `\_SB.PCI0.I2C1.CAMF`, `_HID` `HYV1A11` (SK Hynix, `_DDN` "HYV1A1-CRDD"), I2C bus 1, address **`0x30`**, front camera. According to the SSDB: 2 CSI lanes, MCLK 24 MHz (`0x016E3600`). Power comes from the power resource `PXP` (`_ON`/`_OFF` switch DOVDD/AVDD/DVDD through `IPCS` on the PMIC), `_DEP` on `ICL0` (`INT346F`, camera clock, no Linux driver). Linux has no driver for this sensor (only hi556 / hi846 / hi847).
- **IPU:** `00:05.0` `8086:9830`, subsystem `144d:c18b`, BAR0 16 MB at `0x91000000`. Upstream `intel-ipu6` (7.2.9) does not support `9830`.
- Buttress registers before any driver loads (read only, [ipu-peek.py](ipu-peek.py)): `SECURITY_CTL` `0x0013e800` (bit 16 secure mode), `ISR_STATUS` `0x40` (CSE_CSR_SET), `CSE2IUCSR` 1, `SKU` 0. The layout matches the IPU6 buttress.

## Test 1: intel-ipu6 with 9830 and a selectable profile

[ipu6-lkf-9830-test.patch](ipu6-lkf-9830-test.patch) for `drivers/media/pci/intel/ipu6/ipu6.c` (own ID table with only `9830`, parameter `lkf_ver`), built out of tree against the 7.2.9 headers. Run with [ipu-test.sh](ipu-test.sh) (dead-man switch: 300 s, then SysRq reboot unless you `touch /tmp/ipu-ok`).

| Profile / firmware | Result |
|---|---|
| `lkf_ver=3` IPU6SE (Jasper Lake), linux-firmware `ipu6se_fw.bin` 20210414 | IPC reset OK, firmware loaded and mapped OK, `BOOT_LOAD` to the CSE OK, **`SECURITY_CTL` reaches FW_SETUP_DONE (no AUTH_FAILED)**. Then the bootloader status (`0x15c`) shows **`0xffffffeb` (-21)** instead of `0xb00710ad`, timeout, `probe ... -110`. System stable. |
| `lkf_ver=1` IPU6 (Tiger Lake), `ipu6_fw.bin` 20230925 | Fails earlier with `-5` (EIO), before `BOOT_LOAD`, without an error message. Suspect: runtime PM of the PSYS (`ipu6-bus.c`). Not followed up. |
| `lkf_ver=5` IPU6EP (Alder Lake) | not tried |

Observations:
- Despite a `blacklist` in `/run/modprobe.d`, the in-tree `intel_ipu6_isys` was loaded too (it does not bind because the probe fails). After a successful probe it would start as well.
- `dyndbg=+p` floods the ring buffer with MMU lines: read with `journalctl -k`, not `dmesg`.
- `rmmod intel_ipu6_isys intel_ipu6` works cleanly afterwards.

## Test 2: the Lakefield firmware from the Windows driver

Microsoft Update Catalog, search for `VEN_8086&DEV_9830` or `HYV1A11`: **Intel Corporation - System - 50.18362.4.1914** (2020-05-19, 53 MB). Update IDs starting `73f170f5-` (for `pci\ven_8086&dev_9830`) and `aa34b374-` (for `acpi\hyv1a11`), both the same CAB, **SHA1 `c109e8f659dbb1ed5fb097052351bcbeb5046448`**. An older version is 50.18362.4.1327 (update ID starting `81a45d5c-`). Extract with `cabextract` or `7z x`. Nothing from this package is included here.

**The package is made for exactly this device** (W767 = Galaxy Book S):
- `Bootloader/cpd_btldr_signed.bin` (8 KB, `$CPD` v2, `IUNP` = IPU bootloader)
- `cpd_component_signed.bin` (1.5 MB, `$CPD` v2, `IUNM` = IPU main firmware, strings "glvA0_IPU5", "CSS3.0")
- `pkg_dir.bin` (3 MB, marker `_RDKPUI_`)
- `hi1a1.sys` (sensor driver for HYV1A11, the source for register tables), `graph_settings_Hi1A1_W767_LKF.xml` (sensor modes), `Hi1A1_W767_LKF.aiqb` / `.cpf` (image tuning)
- `iacamera64.sys`, `iaisp64.sys`, `iactrllogic64.sys` (IPU, ISP, control logic / clock)

The Linux `ipu6se_fw.bin` is also `$CPD` / `IUNM`, but with header v1 (length `0x10`); Windows uses v2 (`0x14`). `ipu6_cpd_validate_cpd` reads `hdr_len` from the header, so the format should be accepted.

Run: `FWDIR=<dir> ./ipu-test.sh 3`, where `<dir>/intel/ipu/ipu6se_fw.bin` (and `ipu6_fw.bin`) is a copy of `cpd_component_signed.bin`. The script sets `firmware_class.path` to `<dir>`, loads the patched driver and restores the path.

| Profile / firmware | Result |
|---|---|
| `lkf_ver=3` + Windows `cpd_component_signed.bin` | Firmware accepted ("FW version: 20200225"), `BOOT_LOAD` to the CSE OK, the CSE answers. Then **again `0xffffffeb` (-21)** in the bootloader status, "FW authentication failed", `probe ... -110`. System stable. |

## Conclusion

With the genuine Lakefield firmware the same -21 appears as with the Jasper Lake firmware, so the firmware file is not the cause. Hypothesis: the Lakefield IPU (the string "glvA0_IPU5" suggests an IPU5 derivative rather than IPU6) expects a different boot flow, for example the driver loading the separate bootloader (`IUNP`) and the prebuilt `pkg_dir.bin` itself, instead of handing over only the main firmware like IPU6 does. Finding out would require reverse engineering `iacamera64.sys`. After that, a clock driver (`INT346F`), a sensor driver for `HYV1A11` and libcamera support would still be missing. The chance of a real picture is low, which is why the attempt was stopped here.

If you want to continue, start with:
1. how `iacamera64.sys` loads `cpd_btldr_signed.bin` and `pkg_dir.bin` (order, buttress registers, CSE messages)
2. try `lkf_ver=5` once for completeness
3. register tables in `hi1a1.sys` and the modes in `graph_settings_Hi1A1_W767_LKF.xml` for a sensor driver
