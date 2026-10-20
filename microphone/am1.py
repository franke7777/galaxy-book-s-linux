# Print the $AM1 module header and $CPD entries of AVS/SST DSP firmware files.
# Usage: python3 am1.py <dsp_basefw.bin> ...
import sys,struct
for fn in sys.argv[1:]:
    d=open(fn,'rb').read()
    ext=struct.unpack_from('<I',d,4)[0] if d[:4]==b'$AE1' else 0
    s=d[ext:]
    i=s.find(b'$AM1')
    mid,ln=struct.unpack_from('<II',s,i)
    name=s[i+8:i+16]
    pre,flags,feat=struct.unpack_from('<III',s,i+16)
    ver=struct.unpack_from('<4H',s,i+28)
    hwb,hwl,lo=struct.unpack_from('<III',s,i+36)
    # CPD entries
    n=struct.unpack_from('<I',s,4)[0]; ents=[]
    for k in range(n):
        o=16+k*24; nm=s[o:o+12].rstrip(b'\0').decode(errors='replace'); off,ln2=struct.unpack_from('<II',s,o+12); ents.append(f'{nm}@{hex(off&0x1ffffff)}+{hex(ln2)}')
    print(f'{fn.split("/")[-3] if "fw-" in fn else fn.split("/")[-1]}: ext={hex(ext)} stripped={len(s)} ({len(s)/4096:.1f} pages) AM1@{hex(i)} name={name} preload_pages={pre} flags={hex(flags)} feat={hex(feat)} ver={ver} hwbuf={hex(hwb)}/{hex(hwl)} load_off={hex(lo)}')
    print('   CPD:', ' '.join(ents))
