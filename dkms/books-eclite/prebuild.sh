#!/bin/sh
# Fetch ishtp_eclite.c for the target kernel and add the Lakefield ACPI ID INT3538.
set -e
sh ./kfetch.sh "$1" drivers/platform/x86/intel/ishtp_eclite.c
patch -p5 < eclite-INT3538.patch
