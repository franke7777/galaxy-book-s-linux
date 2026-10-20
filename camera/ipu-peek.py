# Read-only peek at the IPU buttress registers (BAR0 of 00:05.0) before any driver is loaded. Run as root.
import mmap, struct
f = open('/sys/bus/pci/devices/0000:00:05.0/resource0', 'rb')
m = mmap.mmap(f.fileno(), 0x10000, prot=mmap.PROT_READ)
rd = lambda o: struct.unpack('<I', m[o:o+4])[0]
for name, o in [('ISR_STATUS',0x90),('SECURITY_CTL',0x300),('CSE2IUDB0',0x304),('CSE2IUDATA0',0x308),('CSE2IUCSR',0x30c),('SKU',0x314),('BL_STATUS',0x15c)]:
    print(f'{name:13s} 0x{o:03x} = 0x{rd(o):08x}')
print('0x140-0x17c:', ' '.join(f'{rd(o):08x}' for o in range(0x140,0x180,4)))
