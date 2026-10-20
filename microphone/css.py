# Print the CSS/$MN2 header (version, date, SVN) and a short hash of the RSA signing key of DSP firmware files.
# Usage: python3 css.py <dsp_basefw.bin> ...
import sys,struct,hashlib
for fn in sys.argv[1:]:
    d=open(fn,'rb').read()
    i=d.find(b'$MN2'); h=i-28
    t,hl,hv,_,vid,date,size=struct.unpack_from('<7I',d,h)
    v=struct.unpack_from('<4H',d,h+36); svn=struct.unpack_from('<I',d,h+44)[0]
    ms,es=struct.unpack_from('<II',d,h+0x78)
    mod=d[h+0x80:h+0x80+ms*4]
    print(f'{fn.split("/")[-1]:24s} size={len(d)} css@{hex(h)} hdrver={hex(hv)} date={hex(date)} ver={".".join(map(str,v))} svn={svn} mod_dw={ms} exp_dw={es} key={hashlib.sha256(mod).hexdigest()[:16]}')
