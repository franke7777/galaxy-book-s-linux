#!/bin/sh
# One-shot test: load the patched intel-ipu6 (Lakefield 9830) with a dead-man switch.
#   sudo systemd-run --unit=ipu-test --collect ./ipu-test.sh <lkf_ver>
# Confirm with: touch /tmp/ipu-ok (within 300 s), otherwise hard reboot via SysRq.
# Optional: FWDIR=<dir> loads firmware from <dir>/intel/ipu/ via firmware_class.path
# (used for the Windows Lakefield firmware, see README).
VER="${1:-3}"; KO=${KO:-/var/tmp/ipu6-lkf/src/intel-ipu6.ko}; LOG=/var/log/ipu-test.log
FWDIR=${FWDIR:-}
exec >>"$LOG" 2>&1
echo "=== $(date) start, lkf_ver=$VER, fw=${FWDIR:-default}"
rm -f /tmp/ipu-ok
(
  for i in $(seq 300); do [ -e /tmp/ipu-ok ] && exit 0; sleep 1; done
  echo "no confirmation, hard reboot"; dmesg > /var/log/ipu-test-dmesg.log; sync
  echo s > /proc/sysrq-trigger; sleep 2; echo b > /proc/sysrq-trigger
) &
if [ -n "$FWDIR" ]; then
  OLDPATH=$(cat /sys/module/firmware_class/parameters/path)
  printf '%s' "$FWDIR" > /sys/module/firmware_class/parameters/path
fi
mkdir -p /run/modprobe.d
printf 'blacklist intel_ipu6_isys\nblacklist intel_ipu6\n' > /run/modprobe.d/ipu-test.conf
for m in $(modprobe --show-depends intel-ipu6 | awk '/^insmod/ {print $2}' | grep -v '/intel-ipu6.ko'); do
  insmod "$m" 2>/dev/null; done
insmod "$KO" lkf_ver="$VER" dyndbg=+p
echo "insmod rc=$?"
[ -n "$FWDIR" ] && printf '%s' "$OLDPATH" > /sys/module/firmware_class/parameters/path
dmesg > /var/log/ipu-test-dmesg.log; sync
wait
[ -e /tmp/ipu-ok ] && { echo "confirmed"; dmesg > /var/log/ipu-test-dmesg.log; }
