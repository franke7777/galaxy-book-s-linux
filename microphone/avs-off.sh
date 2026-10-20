#!/bin/sh
# Back to the plain HDA driver (state as after a boot with dsp_driver=1)
LOG=/var/log/avs-test.log
exec >>"$LOG" 2>&1
echo "=== $(date) back to snd_hda_intel"
echo -n "" > /sys/module/firmware_class/parameters/path
rmmod snd_soc_avs 2>/dev/null
rmmod snd_soc_avs snd_intel_dspcfg 2>/dev/null
modprobe snd_intel_dspcfg
systemctl restart books-hda.service
sleep 2
systemctl restart books-amp.service
echo "=== done: $(readlink /sys/bus/pci/devices/0000:00:1f.3/driver)"
