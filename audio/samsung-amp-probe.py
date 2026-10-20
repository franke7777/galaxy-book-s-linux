#!/usr/bin/python3 -I
# Research tool: send the Samsung amp sequences known from Linux (alc269.c) to arbitrary I2C addresses.
#   sudo samsung-amp-probe.py v2|v1|off <hex-address> ...   (needs alsa-tools; play audio first)
# Result on this laptop: silence everywhere, the amps stay in reset until coef 0x29 is set (see README).
import sys
import subprocess
def verb(nid, v, p):
    out = subprocess.run(["hda-verb", "/dev/snd/hwC0D0", hex(nid), hex(v), hex(p)], capture_output=True, text=True).stdout
    return int(out.rsplit("value = ", 1)[1], 16)
def coef_w(idx, val):
    verb(0x20, 0x500, idx); verb(0x20, 0x400, val)
def pack(reg, val):
    coef_w(0x23, reg); coef_w(0x25, val); coef_w(0x26, 0xb011)
V2 = lambda left, last: [(0x23e1,0),(0x2012,0x6f),(0x2014,0),(0x201b,1 if left else 2),(0x201d,1 if left else 2),
    (0x201f,0xfe if left else 0xfd),(0x2021,0 if left else 1),(0x2022,0x10),(0x203d,5),(0x203f,3),(0x2050,0x2c),
    (0x2076,0xe),(0x207c,0x4a),(0x2081,3)] + ([(0x2399,3),(0x23a4,0xb5),(0x23a5,1),(0x23ba,0x94)] if last else [(0x23ba,0x8d)])
V1_INIT = [(0x19,0),(0x20,0xc0),(0x22,0x44),(0x23,0x08),(0x24,0x85),(0x25,0x41),(0x35,0x40),(0x36,0x01),
    (0x38,0x81),(0x3a,0x03),(0x3b,0x81),(0x40,0x3e),(0x41,0x07),(0x400,0x1)]
def v2_on(a, left):
    coef_w(0x22, a)
    for r in [(0x23ff,0),(0x203a,0x80)]: pack(*r)
    for r in V2(left, True): pack(*r)
    coef_w(0x89, 0); coef_w(0x22, a)
    for r in [(0x203a,0x81),(0x23ff,1)]: pack(*r)
def v2_off(a):
    coef_w(0x22, a)
    for r in [(0x23ff,0),(0x203a,0x80)]: pack(*r)
def v1_on(a, left):
    coef_w(0x22, a)
    for r in [(0x18, 1 if left else 2), (0x26, 0 if left else 1)] + V1_INIT: pack(*r)
if __name__ == "__main__":
    mode, addrs = sys.argv[1], [int(x, 16) for x in sys.argv[2:]]
    for a in addrs:
        {"v2": lambda: v2_on(a, a % 2 == 0), "off": lambda: v2_off(a), "v1": lambda: v1_on(a, a % 2 == 0)}[mode]()
    print(mode, " ".join(hex(a) for a in addrs))
