#!/bin/sh
# Fetch ufshcd-pci.c for the target kernel and apply the Lakefield HS-G3 cap.
set -e
sh ./kfetch.sh "$1" drivers/ufs/host/ufshcd-pci.c
patch -p4 < ufs-lkf-g3.patch
