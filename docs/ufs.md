# Internal eUFS: why stock Linux fails, and the HS-G3 fix

## Background

The Galaxy Book S has no NVMe or SATA disk. Storage is a soldered **eUFS 3.0** chip (Samsung KLUEG8UHDB-C2D1, 256 GB on the test unit; 512 GB variants exist) on the Intel UFS host controller `8086:98fa` at `00:12.5`. Only a kernel with `ufshcd-pci` and its Intel Lakefield (LKF) support sees it. That support exists upstream since 5.13 (`ufs_intel_lkf_init`, quirk `UFSHCD_QUIRK_BROKEN_AUTO_HIBERN8`, device reset through a Samsung ACPI `_DSM`), and a link stability fix landed in 5.15 ("scsi: ufs: ufs-pci: Fix Intel LKF link stability", commit 1cbc9ad3eecd: set both lanes to 2 before switching to high speed, `PA_TACTIVATE` +2 on the device, NOP-OUT timeout 200 ms). Old "installer does not see the disk" reports from 2021/22 are about older kernels.

On current kernels the symptoms are different:

- **Driver loaded at boot:** link reset loop, boot hangs. Seen identically with Fedora 44 (6.19) and Ubuntu 26.04.1 (7.0): `pa_err 0x80000010`, `dl_err 0x80008002`, `host_reset` twice, `uic_err 0x44`, `Unhandled interrupt`, `dme-peer-get 0x15aa (PA_GRANULARITY) failed`. Installers fail with `sfdisk: cannot open /dev/sda: Input/output error`.
- **Driver blacklisted at boot, loaded later with modprobe:** the disk appears (all partitions visible) after about a second of the same errors. But under sustained load (read-only `dd`) the link breaks again after about 1.3 GB / 38 s, falls back to PWM-G1 with one lane, and I/O hangs (hung task). So "load it late from the initramfs" is not a viable install path either.
- `pcie_aspm=off intel_idle.max_cstate=1` changes nothing, power management is not the cause.

## Measurement: only HS-G4 breaks

A test module with parameters for gear and rate ([../install/live-stick/0001-lkf-gear-cap-v7.0.patch](../install/live-stick/0001-lkf-gear-cap-v7.0.patch)) on the Ubuntu 26.04.1 live stick, kernel 7.0.0-30. Each run: `dd if=/dev/sdb of=/dev/null bs=4M iflag=direct`, read-only, 180 s.

| Setting | Result | Throughput | Errors |
|---|---|---|---|
| HS-G1 Rate A (`lkf_max_gear=1 lkf_hs_rate=1`) | link breaks already when switching rate B to A | - | error loop |
| HS-G1 Rate B (`lkf_max_gear=1`) | 180 s, 41 GB | 228 MB/s | 0 |
| HS-G2 Rate B (`lkf_max_gear=2`) | 180 s, 88 GB | 487 MB/s | 0 |
| HS-G3 Rate B (`lkf_max_gear=3`) | 180 s, 158 GB | 880 MB/s | 0 |
| HS-G4 Rate B (`lkf_max_gear=4`, the default) | `dme-peer-get PA_GRANULARITY (0x15aa) failed` right after the switch, abort after 14 s / 12 GB | 877 MB/s until abort | yes |

- The device reports max HS-G4 Rate B, 2 lanes. G4 brings no extra throughput over G3 here (877 vs. 880 MB/s), so the cap costs nothing.
- With G1 to G3 the module unloads cleanly (`rmmod`). After the G4 failure it hangs, and only a 10 s press of the power button helps (systemd reboot and SysRq b hang too).
- Auto-hibernate is already disabled for LKF in the driver.

Excerpt of the G4 failure (counter-check, same boot):

```
ufshcd 0000:00:12.5: LKF pwr: max g1/1 l2/2 m5/5 r0 -> req g1/1 l2/2 r0
ufshcd 0000:00:12.5: LKF pwr: max g4/4 l2/2 m1/1 r2 -> req g4/4 l2/2 r2
ufshcd 0000:00:12.5: dme-peer-get: attr-id 0x15aa failed 3 retries
ufshcd 0000:00:12.5: ufshcd_check_errors: saved_err 0x4 saved_uic_err 0x4
ufshcd 0000:00:12.5: ufshcd_err_handler started; HBA state eh_non_fatal; ...
ufshcd 0000:00:12.5: ufshcd_check_errors: saved_err 0x4 saved_uic_err 0x44
```

With G3 as boot-time default on the live stick: module loaded after 15.7 s (273 ms), disk with all partitions present, runtime PM renegotiations (at 26 s and 64 s) clean in G3, then 180 s continuous read: 162 GB, 899 MB/s, 0 errors. In the installed system with the module in the initramfs it has been running daily without link errors, including s2idle and hibernate.

## The patch

[../dkms/books-ufs/ufs-lkf-g3.patch](../dkms/books-ufs/ufs-lkf-g3.patch), for 7.2 and later (since 7.0 `pwr_change_notify` only gets `dev_req_params`). It adds `lkf_max_gear` (default 3, 0 = no limit) and clamps `gear_rx`/`gear_tx` in `ufs_intel_lkf_pwr_change_notify()` during `PRE_CHANGE` when switching to an HS mode. No module option needed.

## Kernel version trap

Commit e72323f3b09f "Configure only active lanes during link" (03/2026) makes the link startup on Intel `ufshcd-pci` always fail with `-ENOLINK`. The fix "Skip link param validation when lanes_per_direction is unset" is in 7.2. Do not use 7.1 on this machine.

## Upstream

A proper fix would be an LKF quirk "max HS gear 3" for this device (DMI match on the Samsung 767XCL) in `ufshcd-pci.c`, sent to linux-scsi. The measurements above are the raw data for that.
