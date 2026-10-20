#!/bin/bash
# Set up hibernation on the Galaxy Book S: swap file + resume parameters in GRUB.
# Usage: sudo bash books-hibernate-setup.sh   (idempotent)
#   SWAPFILE=/swapfile SIZE=8G (RAM is 7.6 GiB)
set -euo pipefail

SW=${SWAPFILE:-/swapfile}
SIZE=${SIZE:-8G}

if [ ! -f "$SW" ]; then
  echo ">> creating $SW ($SIZE)"
  fallocate -l "$SIZE" "$SW"
  chmod 600 "$SW"
  mkswap "$SW"
fi

# Low priority: zram (100) stays the normal swap, the file is only for hibernation.
grep -q "^$SW " /etc/fstab || echo "$SW none swap defaults,pri=10 0 0" >> /etc/fstab
swapon --show=NAME | grep -qx "$SW" || swapon -p 10 "$SW"

UUID=$(findmnt -no UUID /)
OFF=$(filefrag -v "$SW" | awk '$1=="0:"{print substr($4,1,length($4)-2)}')
[ -n "$OFF" ] || { echo "!!! could not determine resume_offset"; exit 1; }
echo ">> resume=UUID=$UUID resume_offset=$OFF"

# Set the GRUB line (remove old resume values first), keep a backup
cp -n /etc/default/grub /etc/default/grub.pre-hibernate
sed -i -E 's/ ?resume(_offset)?=[^ "]*//g' /etc/default/grub
sed -i -E "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"([^\"]*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 resume=UUID=$UUID resume_offset=$OFF\"/" /etc/default/grub
grep '^GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo ">> Done. Reboot once, then check: cat /proc/cmdline (resume=...), swapon --show"
echo ">> Then test: systemctl hibernate"
