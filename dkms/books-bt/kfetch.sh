#!/bin/sh
# kfetch.sh <kernelver> <path-in-kernel-tree> [target]
# Downloads one file matching the kernel version from kernel.org (stable tree).
# A copy of this script lives in every DKMS package because DKMS only copies the package directory.
set -e
v=$(echo "$1" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
v=$(echo "$v" | sed -E 's/\.0$//')
curl -fsSL --retry 3 -o "${3:-$(basename "$2")}" "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/$2?h=v$v"
