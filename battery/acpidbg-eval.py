# Run AML commands through the kernel ACPI debugger (/sys/kernel/debug/acpi/acpidbg, needs
# CONFIG_ACPI_DEBUGGER_USER, debugfs and Secure Boot off). Example:
#   sudo python3 acpidbg-eval.py "evaluate \\_SB.BAT1._BST"
import os, sys, time, select
fd = os.open('/sys/kernel/debug/acpi/acpidbg', os.O_RDWR | os.O_NONBLOCK)
def rd(t=2.0):
    out=b''; end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.2)
        if r:
            try:
                d=os.read(fd,65536)
                if d: out+=d
            except BlockingIOError: pass
    return out.decode(errors='replace')
print(rd(1))
for cmd in sys.argv[1:]:
    os.write(fd,(cmd+'\n').encode()); print('>>',cmd); print(rd(3))
os.close(fd)
