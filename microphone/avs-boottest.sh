#!/bin/sh
# DSP boot test, run ONCE right after a reboot:
#   sudo ./avs-boottest.sh /var/tmp/lkf-sst/fw-7068
# Switches audio to the debug AVS module, logs for 35 s, switches back on failure.
# PipeWire of the invoking user ($SUDO_USER, or USER_NAME=...) is stopped during the test.
FW="$1"; LOG=/var/log/avs-boottest.log
AVS_KO=${AVS_KO:-/var/tmp/avs-lkf/sound/soc/intel/avs/snd-soc-avs.ko}
U=${USER_NAME:-$SUDO_USER}
HERE=$(dirname "$(readlink -f "$0")")
[ -d "$FW/intel/avs/lkf" ] || { echo "firmware directory missing: $FW"; exit 1; }
echo "Test running (about 45 s), audio is gone for a moment ..."
[ -n "$U" ] && systemctl --user -M "$U@" stop pipewire.socket pipewire-pulse.socket pipewire pipewire-pulse wireplumber 2>/dev/null
sleep 1
{
echo "=== $(date) boot test, fw=$FW, uptime=$(cut -d' ' -f1 /proc/uptime)s, boot=$(cat /proc/sys/kernel/random/boot_id)"
echo -n "$FW" > /sys/module/firmware_class/parameters/path
echo 0000:00:1f.3 > /sys/bus/pci/drivers/snd_hda_intel/unbind 2>/dev/null
rmmod snd_soc_avs 2>/dev/null; rmmod snd_hda_intel; rmmod snd_intel_dspcfg
modprobe snd_intel_dspcfg dsp_driver=4
insmod "$AVS_KO" ignore_fw_version=1
sleep 45
journalctl -k -b --no-pager | grep -E "snd_soc_avs|LKF-Test"
echo "--- cards:"; cat /proc/asound/cards
if journalctl -k -b --no-pager | grep -q "firmware boot failed"; then
  rmmod snd_soc_avs 2>/dev/null
  "$HERE/avs-off.sh"
  echo "--- back: $(readlink /sys/bus/pci/devices/0000:00:1f.3/driver)"
else
  echo "--- NO 'boot failed': AVS stays bound"
fi
echo "=== end"
} >>"$LOG" 2>&1
[ -n "$U" ] && systemctl --user -M "$U@" start pipewire.socket pipewire-pulse.socket wireplumber 2>/dev/null
echo "Done, log: $LOG"
