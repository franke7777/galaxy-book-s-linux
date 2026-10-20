#!/bin/bash
# Stage 1: install Arch onto the internal eUFS from a live system that already
# runs the eUFS in HS-G3 (see live-stick/). Run as root.
#
# Before running:
#   - partition the eUFS (GPT): ESP 1 GiB vfat + root ext4 (or btrfs)
#   - download archlinux-bootstrap-x86_64.tar.zst (+ .sig) into $WORK and verify the signature
#
# Variables (override on the command line, e.g. DISK=/dev/sda ./stage1-...):
WORK=${WORK:-/root/archboot}       # directory with the bootstrap tarball
DISK=${DISK:-/dev/sdb}             # internal eUFS as seen from the live stick (often sdb, the stick is sda)
ROOT_PART=${ROOT_PART:-${DISK}2}
ESP_PART=${ESP_PART:-${DISK}1}
TARGET=${TARGET:-/mnt/arch}
set -ex
cd "$WORK"
[ -d root.x86_64 ] || tar --zstd -xpf archlinux-bootstrap-x86_64.tar.zst --numeric-owner
R=$WORK/root.x86_64
mount --bind $R $R
mkdir -p $R/mnt "$TARGET"
mountpoint -q "$TARGET" || mount "$ROOT_PART" "$TARGET"
mkdir -p "$TARGET/boot" && (mountpoint -q "$TARGET/boot" || mount "$ESP_PART" "$TARGET/boot")
mount --rbind "$TARGET" $R/mnt
for d in proc sys dev run; do mount --rbind /$d $R/$d; mount --make-rslave $R/$d; done
cp /etc/resolv.conf $R/etc/resolv.conf
# Pick mirrors close to you (https://archlinux.org/mirrorlist/)
cat > $R/etc/pacman.d/mirrorlist <<M
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
M
sed -i "s/^#ParallelDownloads.*/ParallelDownloads = 5/" $R/etc/pacman.conf
chroot $R /bin/bash -c "pacman-key --init && pacman-key --populate archlinux && pacstrap -K /mnt base linux linux-headers linux-firmware intel-ucode base-devel dkms git networkmanager bluez bluez-utils openssh sudo nano vim zram-generator grub efibootmgr"
genfstab -U "$TARGET" > /tmp/fstab.gen 2>/dev/null || chroot $R /bin/bash -c "genfstab -U /mnt" > /tmp/fstab.gen
cp /tmp/fstab.gen "$TARGET/etc/fstab"
cp $R/etc/pacman.d/mirrorlist "$TARGET/etc/pacman.d/mirrorlist"
echo STAGE1-OK
echo "Next: copy this repository to $TARGET/root/books-setup and run stage2 inside arch-chroot."
