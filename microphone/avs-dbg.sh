#!/bin/sh
# Load the debug AVS module (logs ROM states for 30 s, see avs-loader-rom-trace.patch) with firmware from $1.
# Expects dsp_driver=4 (avs-on.sh ran before).
FW="$1"; LOG=/var/log/avs-test.log
AVS_KO=${AVS_KO:-/var/tmp/avs-lkf/sound/soc/intel/avs/snd-soc-avs.ko}
exec >>"$LOG" 2>&1
echo "=== $(date) debug AVS, fw=$FW"
echo -n "$FW" > /sys/module/firmware_class/parameters/path
rmmod snd_soc_avs 2>/dev/null
insmod "$AVS_KO" ignore_fw_version=1
sleep 36
journalctl -k --since "-45s" --no-pager | grep -i -E "avs|1f.3"
echo "=== done"
