#!/usr/bin/python3 -I
# Research tool: amp init using the tables found in the Windows driver RTKVHD64.sys 6.0.9689.1
# (tables at file offset 0x1c3628: reset 2000:1 + 10 ms, gen-2 init, then 23b9/23e0/23e1, then enable).
# Result: still silent. The missing piece was coef 0x29 (see books-amp-c18b.py).
#   sudo samsung-amp-win.py <hex-address> ...   (order = table 1..4: L, R, L, R)
import sys, time, subprocess
def verb(nid, v, p):
    out = subprocess.run(["hda-verb", "/dev/snd/hwC0D0", hex(nid), hex(v), hex(p)], capture_output=True, text=True).stdout
    return int(out.rsplit("value = ", 1)[1], 16)
def coef_w(idx, val):
    verb(0x20, 0x500, idx); verb(0x20, 0x400, val)
def pack(reg, val):
    if reg == 0xffff:
        time.sleep(val / 1000); return
    coef_w(0x23, reg); coef_w(0x25, val); coef_w(0x26, 0xb011)
COMMON = [(0x2022,0x10),(0x203d,5),(0x203f,3),(0x2050,0x2c),(0x2076,0xe),(0x207c,0x4a),(0x2081,3)]
def table(left, first_pair):
    t = [(0x2000,1),(0xffff,10),(0x23ff,0),(0x203a,0x80),(0x23e1,0),(0x2012,0x6f),(0x2014,0),
         (0x201b,1 if left else 2),(0x201d,1 if left else 2),(0x201f,0xfe if left else 0xfd),(0x2021,0 if left else 1)] + COMMON
    t += [(0x2399,3),(0x23a4,0xb5),(0x23a5,1),(0x23ba,0x94)] if first_pair else [(0x23ba,0x8d),(0x23b9,0),(0x23e0,0x20),(0x23e1,1)]
    return t
addrs = [int(x, 16) for x in sys.argv[1:]]
for n, a in enumerate(addrs):
    coef_w(0x22, a)
    for r in table(n % 2 == 0, n < 2): pack(*r)
for a in addrs:
    coef_w(0x22, a)
    for r in [(0x23ff,0),(0x203a,0x80),(0x203a,0x81),(0x23ff,1)]: pack(*r)
print("win-init", " ".join(hex(a) for a in addrs))
