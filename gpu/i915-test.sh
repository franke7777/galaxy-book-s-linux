#!/bin/sh
# One-shot test: load a patched i915 (Lakefield 9840) by hand, with a dead-man switch.
#   sudo systemd-run --unit=i915-test --collect /var/tmp/i915-lkf/i915-test.sh /var/tmp/i915-lkf/i915.ko
# Confirm with: touch /tmp/i915-ok  (within 300 s), otherwise hard reboot via SysRq.
KO="$1"; LOG=/var/log/i915-test.log
exec >>"$LOG" 2>&1
echo "=== $(date) start, ko=$KO"
rm -f /tmp/i915-ok
# Start the watchdog first, independent of insmod (which hung during the first test)
(
  for i in $(seq 300); do [ -e /tmp/i915-ok ] && exit 0; sleep 1; done
  echo "no confirmation, hard reboot"; dmesg > /var/log/i915-test-dmesg.log; sync
  echo s > /proc/sysrq-trigger; sleep 2; echo b > /proc/sysrq-trigger
) &
for m in $(modprobe --show-depends i915 | awk '/^insmod/ {print $2}' | grep -v '/i915.ko'); do
  insmod "$m" 2>/dev/null; done
insmod "$KO"
echo "insmod rc=$?"
# Lakefield: no runtime PM, otherwise 00:02.0 goes to D3 and the simpledrm display freezes
echo on > /sys/bus/pci/devices/0000:00:02.0/power/control
dmesg > /var/log/i915-test-dmesg.log; sync
wait
[ -e /tmp/i915-ok ] && { echo "confirmed"; dmesg > /var/log/i915-test-dmesg.log; }
