#!/usr/bin/python3 -I
# Turn on the speaker amplifiers of the Galaxy Book S (ALC298, subsystem 144d:c18b) with the same
# register sequence the Windows driver uses (books-amp-c18b.seq, next to this script).
#   sudo books-amp-c18b.py [init|on|off]   (no argument: init + on)
import sys, time, os, fcntl, struct
import glob
# Find the codec hwdep node of the card with the ALC298: snd_hda_intel = hwC0D0, AVS = hwC1D0
DEV = next((f"/dev/snd/hwC{c.split('card')[1].split('/')[0]}D0" for c in sorted(glob.glob("/proc/asound/card*/codec#0"))
            if "ALC298" in open(c).read(4096)), "/dev/snd/hwC0D0")
SEQ = os.path.join(os.path.dirname(os.path.realpath(__file__)), "books-amp-c18b.seq")
AMPS = [0x3c, 0x38, 0x3d, 0x39]
# Talk to the codec directly via ioctl like hda-verb does (HDA_IOCTL_VERB_WRITE) instead of spawning
# hda-verb per command: ~6000 process starts cost 10-14 s after every resume.
HDA_IOCTL_VERB_WRITE = 0xC0084811  # _IOWR('H', 0x11, struct hda_verb_ioctl {u32 verb; u32 res;})
fd = os.open(DEV, os.O_RDWR)
def verb(nid, v, p):
    buf = bytearray(struct.pack("II", (nid << 24) | (v << 8) | p, 0))
    fcntl.ioctl(fd, HDA_IOCTL_VERB_WRITE, buf)
    return struct.unpack("II", buf)[1]
def coef_r(idx):
    verb(0x20, 0x500, idx); return verb(0x20, 0xc00, 0)
def coef_w(idx, val):
    verb(0x20, 0x500, idx); verb(0x20, 0x400, val)
def amp(addr, reg, val, nbytes=1):
    # I2C bridge inside the codec: 0x22 address, 0x23 register, 0x24 value high, 0x25 value low,
    # 0x26 start (0xb011 = 1-byte value, 0xb017 = 3-byte value)
    coef_w(0x22, addr); coef_w(0x23, reg); coef_w(0x24, val >> 16); coef_w(0x25, val & 0xffff)
    coef_w(0x26, 0xb017 if nbytes == 3 else 0xb011)
def init():
    for line in open(SEQ):
        f = line.split()
        if not f or f[0].startswith("#"): continue
        if f[0] == "coef29": coef_w(0x29, (coef_r(0x29) & ~3) | int(f[1], 16))
        elif f[0] == "sleep": time.sleep(int(f[1]) / 1000)
        else: amp(int(f[0], 16), int(f[1], 16), int(f[2], 16), int(f[3]))
def on():
    time.sleep(0.1)
    for a in AMPS: amp(a, 0x203a, 0x81); amp(a, 0x23ff, 1)
def off():
    for a in AMPS: amp(a, 0x23ff, 0); amp(a, 0x203a, 0x80)
mode = sys.argv[1] if len(sys.argv) > 1 else "all"
if mode in ("init", "all"): init()
if mode in ("on", "all"): on()
if mode == "off": off()
print("ok", mode, "coef29=%#x" % coef_r(0x29))
