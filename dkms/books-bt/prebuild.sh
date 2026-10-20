#!/bin/sh
# Fetch drivers/bluetooth (sources + Makefile) for the target kernel, apply the
# hci_intel serdev series (0001-0004) plus the drvdata fix (0005) and build only hci_uart.
set -e
v=$(echo "$1" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/; s/\.0$//')
sh ./kfetch.sh "$1" drivers/bluetooth/Makefile Makefile.kernel
for f in $(curl -fsSL "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/bluetooth?h=v$v" | grep -o "drivers/bluetooth/[A-Za-z0-9_-]*\.[ch]" | sort -u); do
  sh ./kfetch.sh "$1" "$f"
done
for p in 0001-0004-caiyu-hci_intel-ccp-serdev.patch 0005-hci_intel-serdev-set-drvdata.patch; do patch -p3 < $p; done
{ echo "obj-m := hci_uart.o"; grep -E "^hci_uart-" Makefile.kernel; } > Makefile
