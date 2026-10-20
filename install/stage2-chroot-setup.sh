#!/bin/bash
# Stage 2: runs inside the new system (arch-chroot /mnt/arch), as root.
#   USERNAME=alice ./stage2-chroot-setup.sh
# Expects this repository at $S (default /root/books-setup).
#
# Changes compared to a stock Arch install, all needed on this laptop:
#   - patched UFS driver (HS-G3) as DKMS and inside the initramfs, root lives on the eUFS
#   - GRUB instead of systemd-boot (systemd-boot shows its menu, then a black screen on this firmware)
#   - linux/linux-headers on IgnorePkg, kernel updates only via books-kernel-update
S=${S:-/root/books-setup}
USERNAME=${USERNAME:?set USERNAME=<your login name>}
HOSTNAME_=${HOSTNAME_:-books}
TIMEZONE=${TIMEZONE:-UTC}
LOCALE=${LOCALE:-en_US.UTF-8}
KEYMAP=${KEYMAP:-us}
set -ex
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc || true
sed -i "s/^#$LOCALE/$LOCALE/; s/^#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
printf "KEYMAP=%s\n" "$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME_" > /etc/hostname
printf "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s\n" "$HOSTNAME_" > /etc/hosts
# zram instead of a swap partition
printf "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n" > /etc/systemd/zram-generator.conf

# DKMS modules: UFS (vital), battery (eclite), Bluetooth (hci_uart). books-i915 is optional, see gpu/.
k=$(ls /usr/lib/modules | head -1)
for p in books-ufs books-eclite books-bt; do
  rm -rf /usr/src/$p-1.0 && cp -r "$S/dkms/$p" /usr/src/$p-1.0
  dkms install $p/1.0 -k "$k"
done
install -m644 "$S/dkms/books-ish.service" /etc/systemd/system/books-ish.service

# initramfs: always include the patched UFS driver (G3)
sed -i "s/^MODULES=.*/MODULES=(ufshcd_core ufshcd_pci)/" /etc/mkinitcpio.conf
mkinitcpio -P
lsinitcpio /boot/initramfs-linux.img | grep -E "updates/dkms/ufshcd-pci" || { echo "!!! patched ufshcd-pci missing from initramfs, do not reboot"; exit 1; }

# Bootloader: GRUB. Also install to the removable fallback path EFI/BOOT/BOOTX64.EFI.
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"/; s/^#\?GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' /etc/default/grub
grep -q '^GRUB_GFXPAYLOAD_LINUX' /etc/default/grub || echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Desktop packages (Sway; adjust to taste)
pacman -S --noconfirm --needed sway swaybg swayidle swaylock foot fuzzel waybar mako firefox noto-fonts ttf-font-awesome xdg-desktop-portal-wlr polkit man-db htop less
# Kernel updates only on purpose (books-kernel-update)
sed -i "s/^#IgnorePkg.*/IgnorePkg = linux linux-headers/" /etc/pacman.conf
install -m755 "$S/install/books-kernel-update" /usr/local/bin/books-kernel-update

# User. The password is asked for interactively, nothing is hardcoded.
id "$USERNAME" || useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Set a password for $USERNAME:"
until passwd "$USERNAME"; do :; done
# wheel may use sudo WITH password
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
# Optional: SSH public key ($S/authorized_keys)
if [ -f "$S/authorized_keys" ]; then
  H=$(getent passwd "$USERNAME" | cut -d: -f6)
  install -d -m700 -o "$USERNAME" -g "$USERNAME" "$H/.ssh"
  install -m600 -o "$USERNAME" -g "$USERNAME" "$S/authorized_keys" "$H/.ssh/authorized_keys"
  printf "PasswordAuthentication no\nKbdInteractiveAuthentication no\n" > /etc/ssh/sshd_config.d/10-books.conf
  systemctl enable sshd
fi
# Start Sway on tty1 after login (software rendering until books-i915 is set up, see gpu/)
H=$(getent passwd "$USERNAME" | cut -d: -f6)
cat >> "$H/.bash_profile" <<B
if [ -z "\$WAYLAND_DISPLAY" ] && [ "\$(tty)" = /dev/tty1 ]; then
  export WLR_RENDERER=pixman MOZ_ENABLE_WAYLAND=1
  exec sway
fi
B
chown "$USERNAME:$USERNAME" "$H/.bash_profile"
# Wi-Fi: configure after the first boot with nmtui / nmcli
systemctl enable NetworkManager bluetooth books-ish fstrim.timer systemd-timesyncd
echo STAGE2-OK
