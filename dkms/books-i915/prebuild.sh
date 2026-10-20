#!/bin/sh
# Fetch drivers/gpu/drm/i915 for the target kernel (kernel.org tarball, cached) and apply the LKF patch.
set -e
v=$(echo "$1" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/' | sed -E 's/\.0$//')
major=${v%%.*}
cache=${BOOKS_I915_CACHE:-/var/cache/books-i915}; mkdir -p "$cache"
tar="$cache/linux-$v.tar.xz"
if [ ! -s "$tar" ]; then
  curl -fsSL --retry 3 -o "$tar.part" "https://cdn.kernel.org/pub/linux/kernel/v$major.x/linux-$v.tar.xz"
  mv "$tar.part" "$tar"
fi
# remove cached tarballs of other versions (~160 MB each)
find "$cache" -name 'linux-*.tar.xz' ! -name "linux-$v.tar.xz" -delete
rm -rf i915
tar -xJf "$tar" --strip-components=4 "linux-$v/drivers/gpu/drm/i915"
tar -xJf "$tar" --strip-components=4 -C i915 "linux-$v/drivers/platform/x86/intel_ips.h"
cd i915
patch -p1 < ../i915-lkf.patch
# Out-of-tree build: make tracepoint include paths absolute, use the local copy of intel_ips.h
grep -rl '\.\./\.\./drivers/gpu/drm/i915' --include=*.h . | xargs sed -i "s|\.\./\.\./drivers/gpu/drm/i915|$PWD|g"
sed -i 's|"\.\./\.\./\.\./platform/x86/intel_ips.h"|"intel_ips.h"|' gt/intel_rps.c
