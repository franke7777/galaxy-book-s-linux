#!/bin/sh
# Move audio from snd_hda_intel to AVS at runtime, DSP firmware from $1
# (a directory containing intel/avs/lkf/dsp_basefw.bin). Research tool, see README:
# switching at runtime leaves the DSP stuck; only a boot with AVS loaded first works.
FW="$1"; LOG=/var/log/avs-test.log
exec >>"$LOG" 2>&1
echo "=== $(date) AVS on, fw=$FW"
echo -n "$FW" > /sys/module/firmware_class/parameters/path
echo 0000:00:1f.3 > /sys/bus/pci/drivers/snd_hda_intel/unbind 2>/dev/null
rmmod snd_soc_avs snd_hda_intel snd_intel_dspcfg
modprobe snd_intel_dspcfg dsp_driver=4
modprobe snd_soc_avs ignore_fw_version=1
sleep 8
journalctl -k --since "-20s" --no-pager | grep -i -E "avs|1f.3|dsp|firmware"
echo "=== done"
