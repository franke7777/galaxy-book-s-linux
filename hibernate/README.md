# Hibernate and lid policy

s2idle draws about 2 W and there is no wake timer (see [../docs/power.md](../docs/power.md)), so suspend-then-hibernate is not possible. Instead:

- **On AC:** lid closed = s2idle.
- **On battery:** lid closed = stay awake, lock, keyboard light off, hibernate after 20 minutes (only awake time counts, the countdown pauses on AC). Awake with the lid closed draws about 2.6 W, so 20 minutes cost about 1 Wh.

## Files

| File | Target | Purpose |
|---|---|---|
| [books-hibernate-setup.sh](books-hibernate-setup.sh) | run once | creates `/swapfile` (8 GB, priority 10, zram stays at 100), computes `resume_offset`, adds `resume=UUID=... resume_offset=...` to GRUB (backup `/etc/default/grub.pre-hibernate`) |
| [10-books-lid.conf](10-books-lid.conf) | `/etc/systemd/logind.conf.d/` | `HandleLidSwitch=ignore`, `HandleLidSwitchExternalPower=suspend` |
| [books-lidwait](books-lidwait) | `/usr/local/bin/` | lid closed on battery: lock, light off, hibernate after `BOOKS_LID_WAIT` seconds (default 1200) |
| [books-lidwait.service](books-lidwait.service) | `/etc/systemd/system/` | runs it |

```
sudo bash hibernate/books-hibernate-setup.sh    # then reboot once
sudo install -Dm644 hibernate/10-books-lid.conf /etc/systemd/logind.conf.d/10-books-lid.conf
sudo install -m755 hibernate/books-lidwait /usr/local/bin/
sudo install -m644 hibernate/books-lidwait.service /etc/systemd/system/
sudo systemctl enable --now books-lidwait.service
```

The initramfs needs the `resume` hook if you use a busybox initramfs (the default systemd hook handles `resume=` itself). `systemctl hibernate` resumes cleanly (same boot ID). Set UPower `CriticalPowerAction=Auto` (or `Hibernate`) in `/etc/UPower/UPower.conf` so a critically low battery hibernates.

To test with a short countdown:
```
sudo systemctl set-environment BOOKS_LID_WAIT=60 && sudo systemctl restart books-lidwait
# back:
sudo systemctl unset-environment BOOKS_LID_WAIT && sudo systemctl restart books-lidwait
```

After resume from hibernate, `ucsi_acpi ... failed to re-enable notifications (-110)` appears once; USB-C charging kept working.
