# Research tool: python rtk-emu.py RTKVHD64.sys <function-hex> [off=value ...] [rdx=1]  (venv with unicorn + pefile)
# The hooked call targets (amp write, coef write, sleep) are addresses inside RTKVHD64.sys 6.0.9689.1;
# other driver versions need other addresses. The driver itself is NOT part of this repository.
# Emulates one function of RTKVHD64.sys and logs codec / amplifier register writes.
import sys, struct, pefile
from unicorn import *
from unicorn.x86_const import *
path, func = sys.argv[1], int(sys.argv[2], 16)
pe = pefile.PE(path)
base = pe.OPTIONAL_HEADER.ImageBase
img = pe.get_memory_mapped_image()
mu = Uc(UC_ARCH_X86, UC_MODE_64)
size = (len(img) + 0xfff) & ~0xfff
mu.mem_map(base, size); mu.mem_write(base, img)
mu.mem_map(0, 0x400000)              # NULL pointer + small offsets read zeros
OBJ = 0x10000000; mu.mem_map(OBJ, 0x100000)
STK = 0x7f000000; mu.mem_map(STK, 0x100000)
END = 0x60000000; mu.mem_map(END, 0x1000)
rsp = STK + 0x80000
mu.mem_write(rsp, struct.pack('<Q', END))
mu.reg_write(UC_X86_REG_RSP, rsp); mu.reg_write(UC_X86_REG_RCX, OBJ)
REGS = {"rdx": UC_X86_REG_RDX, "r8": UC_X86_REG_R8}
for k, v in [kv.split('=') for kv in sys.argv[3:]]:   # preset object fields: off=value
    if k in REGS: mu.reg_write(REGS[k], int(v, 16)); continue
    mu.mem_write(OBJ + int(k, 16), struct.pack('<I', int(v, 16)))
R = lambda r: mu.reg_read(r)
q = lambda a: struct.unpack('<Q', mu.mem_read(a, 8))[0]
d = lambda a: struct.unpack('<I', mu.mem_read(a, 4))[0]
def hook(mu, addr, sz, _):
    b = bytes(mu.mem_read(addr, 6))
    if b[0] == 0xe8:
        tgt = (addr + 5 + struct.unpack('<i', b[1:5])[0]) & 0xffffffffffffffff; n = 5
    elif b[:2] == b'\xff\x15':
        tgt = q(addr + 6 + struct.unpack('<i', b[2:6])[0]); n = 6
    else:
        return
    sp = R(UC_X86_REG_RSP)
    if tgt == 0x1400fd3b0:
        cnt, ptr = d(sp + 0x28), q(sp + 0x30)
        pairs = [struct.unpack('<II', mu.mem_read(ptr + 8 * i, 8)) for i in range(cnt)]
        print(f"AMP {R(UC_X86_REG_EDX) & 0xff:#04x} " + " ".join(f"{r:#06x}={v:#x}" for r, v in pairs) + f"   (r8={R(UC_X86_REG_R8)&0xffff} r9={R(UC_X86_REG_R9)&0xffffffff} a20={d(sp+0x20)} a38={d(sp+0x38)} a40={d(sp+0x40)})")
    elif tgt == 0x1403d1dd8:
        print(f"COEF idx={R(UC_X86_REG_EDX)&0xffff:#x} val={R(UC_X86_REG_R8)&0xffffffff:#x} mask={R(UC_X86_REG_R9)&0xffffffff:#x}")
    elif tgt == 0x1400c5710:
        print(f"SLEEP {R(UC_X86_REG_ECX)&0xffffffff} ms")
    else:
        print(f"  call {tgt:#x}")
    mu.reg_write(UC_X86_REG_RAX, 0)
    mu.reg_write(UC_X86_REG_RIP, addr + n)
mu.hook_add(UC_HOOK_CODE, hook)
mu.emu_start(func, END, count=2_000_000)
print("END")
