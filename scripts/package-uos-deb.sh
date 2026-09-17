#!/usr/bin/env bash
# Validate the UOS ABI before copying a package into release-assets.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C
version="$(node -p "require('./package.json').version")"
if [[ $# -gt 0 ]]; then
  package="$1"
else
  bundle="${CARGO_TARGET_DIR:-src-tauri/target}/release/bundle/deb"
  mapfile -t packages < <(find "$bundle" -maxdepth 1 -type f -name '*.deb' | sort)
  [[ ${#packages[@]} -eq 1 ]] || { echo "Expected exactly one .deb in $bundle" >&2; exit 1; }
  package="${packages[0]}"
fi
[[ -f "$package" ]]
[[ "$(dpkg-deb -f "$package" Package)" == cc-switch ]]
[[ "$(dpkg-deb -f "$package" Version)" == "$version" ]]
[[ "$(dpkg-deb -f "$package" Architecture)" == amd64 ]]
depends="$(dpkg-deb -f "$package" Depends)"
for dependency in libwebkit2gtk-4.0-37 libgtk-3-0 libayatana-appindicator3-1; do
  grep -Eq "(^|, )${dependency//./\\.}([ ,(]|$)" <<< "$depends" || {
    echo "Missing UOS dependency: $dependency" >&2; exit 1;
  }
done
if grep -Eq 'libwebkit2gtk-4\.1|libsoup-3\.0' <<< "$depends"; then
  echo 'The package requires the incompatible WebKitGTK 4.1 / libsoup 3 ABI' >&2
  exit 1
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
dpkg-deb -x "$package" "$work"
binary="$work/usr/bin/cc-switch"
[[ -x "$binary" ]]
readelf -h "$binary" | grep -q 'Advanced Micro Devices X86-64'
# Inspect the ELF rather than relying only on the generated Debian Depends field.
readelf --version-info "$binary" > "$work/versions.txt"
glibc="$(grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' "$work/versions.txt" | sort -Vu | tail -n 1)"
[[ -n "$glibc" ]]
highest="$(printf '%s\n' "${glibc#GLIBC_}" 2.28 | sort -V | tail -n 1)"
[[ "$highest" == "2.28" ]] || {
  echo "UOS 20 requires glibc <= 2.28; binary requires $glibc" >&2; exit 1;
}
readelf -d "$binary" > "$work/dynamic.txt"
grep -q 'libwebkit2gtk-4.0.so.37' "$work/dynamic.txt"
if grep -Eq 'libwebkit2gtk-4\.1|libsoup-3\.0|RPATH|RUNPATH' "$work/dynamic.txt"; then
  echo 'Incompatible ABI or build-machine library path in executable' >&2; exit 1
fi
# Validate the menu entry without installing or launching the application.
desktop-file-validate "$work/usr/share/applications/cc-switch.desktop"
mkdir -p release-assets
name="CC-Switch-v${version}-UOS-amd64.deb"
cp "$package" "release-assets/$name"
dpkg-deb -I "$package" > release-assets/control.txt
{
  echo "CC Switch $version — UOS amd64"
  echo "Maximum required glibc symbol version: $glibc"
  echo "Depends: $depends"
  cat "$work/dynamic.txt"
} > release-assets/abi-report.txt
(cd release-assets && sha256sum "$name" > SHA256SUMS && sha256sum -c SHA256SUMS)
printf 'Validated package: release-assets/%s\n' "$name"
