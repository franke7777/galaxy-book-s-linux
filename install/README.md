# Installation

The root file system goes onto the internal eUFS. The eUFS only works with the patched `ufshcd-pci` (HS-G3 cap, see [../docs/ufs.md](../docs/ufs.md)), so every step must make sure the stock driver never brings the link up in HS-G4.

**Do not install from the Arch ISO.** Its kernel loads the unpatched `ufshcd_pci` at boot, the link negotiates HS-G4 and breaks. Install from a live system that already runs the eUFS in G3 instead.

## 0. Before you start

- BIOS (F2): Secure Boot **off**, Fast BIOS Mode **off**. The DKMS modules are unsigned.
- This wipes Windows. There is no Samsung recovery image to download. If you might want Windows back, image the whole eUFS first (from the live stick, after step 1), for example `dd if=/dev/sdb bs=4M status=progress | zstd > /some/external/disk/eufs.img.zst`.
- The boot menu is F10.

## 1. Live stick with a working eUFS

Any live distribution with persistence works. It was done with Ubuntu 26.04.1 (kernel 7.0). The idea:

1. Boot the stick with the stock UFS driver disabled. At the GRUB menu press `e` and add before `---`:
   `modprobe.blacklist=ufshcd_pci rd.driver.blacklist=ufshcd_pci`
   Make it permanent in the stick's GRUB config once persistence works.
2. Build a G3-capped `ufshcd-pci.ko` for the stick's kernel:
   - get `drivers/ufs/host/ufshcd-pci.c` for exactly that kernel version (distribution kernel source package, or kernel.org for the matching tag)
   - apply [live-stick/0001-lkf-gear-cap-v7.0.patch](live-stick/0001-lkf-gear-cap-v7.0.patch). It was written against v7.0, where `pwr_change_notify` still has the `dev_max_params` argument. For 7.2 and later use [../dkms/books-ufs/ufs-lkf-g3.patch](../dkms/books-ufs/ufs-lkf-g3.patch) instead. The v7.0 patch adds two parameters, `lkf_max_gear` and `lkf_hs_rate`, plus a log line with the negotiated values (`LKF pwr: max g4/4 ... -> req g3/3 ...`).
   - build with [live-stick/Makefile](live-stick/Makefile) (needs the headers for the running kernel), then copy the result to `/lib/modules/$(uname -r)/updates/ufshcd-pci-g3.ko`
3. Install [live-stick/books-ufs-g3.service](live-stick/books-ufs-g3.service) and enable it. It loads the module early with `lkf_max_gear=3`.
4. Check: `lsblk` shows the eUFS (usually `sdb`, the stick is `sda`), `dmesg | grep -i ufs` shows no link errors.

On the test device the module loaded in 273 ms during boot, and 180 s of continuous reading gave 162 GB at 899 MB/s with zero errors.

Keep this stick. It is your rescue system.

## 2. Partition the eUFS

GPT, for example:

| Partition | Size | Type |
|---|---|---|
| `sdb1` | 1 GiB | EFI system partition, vfat |
| `sdb2` | rest | Linux root, ext4 (btrfs also fine) |

A 10 GB write test with checksum before the install gave 266 MB/s and no errors.

## 3. Stage 1: pacstrap from the bootstrap tarball

The live stick is not Arch, so use the Arch bootstrap tarball:

1. Download `archlinux-bootstrap-x86_64.tar.zst` and its `.sig` from an Arch mirror into a work directory (default `/root/archboot`), verify the signature with the Arch release key.
2. Run as root:
   ```
   sudo DISK=/dev/sdb WORK=/root/archboot ./stage1-bootstrap-pacstrap.sh
   ```
   It extracts the tarball, mounts the eUFS partitions under `/mnt/arch`, chroots into the bootstrap environment and runs `pacstrap` with `base linux linux-headers linux-firmware intel-ucode base-devel dkms git networkmanager bluez bluez-utils openssh sudo zram-generator grub efibootmgr` and a few editors, then writes `fstab`.

Edit the mirror list in the script to use mirrors near you.

## 4. Stage 2: inside the new system

Copy this repository into the new system and run stage 2 inside `arch-chroot`:

```
sudo cp -r /path/to/galaxy-book-s-linux /mnt/arch/root/books-setup
sudo arch-chroot /mnt/arch
USERNAME=yourname TIMEZONE=Europe/Berlin LOCALE=en_US.UTF-8 KEYMAP=us /root/books-setup/install/stage2-chroot-setup.sh
```

What it does:

- locale, keymap, timezone, hostname `books`, zram instead of a swap partition
- builds the DKMS packages `books-ufs`, `books-eclite`, `books-bt` (they download the matching driver sources from kernel.org, so network is required in the chroot) and installs `books-ish.service`
- `MODULES=(ufshcd_core ufshcd_pci)` in `/etc/mkinitcpio.conf`, rebuilds the initramfs and **aborts if the patched `updates/dkms/ufshcd-pci` module is not inside**
- installs GRUB (normal entry plus the removable fallback path `EFI/BOOT/BOOTX64.EFI`), `GRUB_GFXPAYLOAD_LINUX=keep`, `loglevel=3`
- installs Sway and a few desktop packages (adjust to taste)
- puts `linux linux-headers` on `IgnorePkg` and installs `books-kernel-update` to `/usr/local/bin`
- creates your user in `wheel` and asks for the password interactively. `wheel` gets sudo **with** password
- optional: if `authorized_keys` exists in the repository root, it is installed for your user and SSH password login is disabled
- enables NetworkManager, bluetooth, `books-ish`, `fstrim.timer`, `systemd-timesyncd`

Wi-Fi is configured after the first boot (`nmtui`).

### Why GRUB and not systemd-boot

systemd-boot shows its menu on this firmware, but after Enter the screen stays black: no network, no journal, also with `loglevel=7` and with `module_blacklist=i915`. The likely cause is the old Samsung firmware (P07AJD, 2020) in combination with the EFI stub start from systemd-boot. GRUB (`grub-install --target=x86_64-efi --bootloader-id=GRUB`, `GRUB_GFXPAYLOAD_LINUX=keep`) boots immediately. Also install GRUB to the removable path (`grub-install --removable`) so the firmware fallback works, and remove stale boot entries with `efibootmgr`.

## 5. First boot

Expected on the test device: root on `/dev/sda2` (without the stick the eUFS becomes `sda`), `ufshcd_pci` from `updates/dkms`, `lkf_max_gear=3`, no link errors, battery visible, Bluetooth on, no failed units. Boot time 24 s (7 s firmware, 8 s loader, 9 s Linux). RAM use with Sway: 531 MB.

The display runs on `simpledrm` with software rendering (`WLR_RENDERER=pixman`) until you set up [../gpu/](../gpu/README.md).

## Kernel updates

Root lives on the eUFS. If the UFS module is not built for a new kernel, the system does not boot. Therefore:

- `IgnorePkg = linux linux-headers` in `/etc/pacman.conf`
- update the kernel only with [books-kernel-update](books-kernel-update). It updates `linux` + `linux-headers` (DKMS builds all `books-*` modules automatically), then checks that `ufshcd_pci`, `intel_ishtp_eclite`, `hci_uart` and `i915` come from `updates/dkms` for the new version, and that the patched `ufshcd-pci` is inside the initramfs. It tells you clearly whether it is safe to reboot.
- If it says "DO NOT REBOOT": `sudo dkms install books-ufs/1.0 -k <version>` and `sudo mkinitcpio -P`, then run the checks again.
- Emergency: boot the live stick, mount the root partition, `arch-chroot`, fix as above.

A missing `books-i915` is not fatal. Sway then falls back to Pixman.
