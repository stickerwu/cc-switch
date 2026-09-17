#!/usr/bin/env bash
# Installs the already-built UOS package for the current user; does not use sudo.
set -euo pipefail
cd "$(dirname "$0")/.."
version=3.20.3
package="${1:-src-tauri/target/release/bundle/deb/cc-switch_${version}_amd64.deb}"
[[ -f "$package" ]] || { echo "Package not found: $package" >&2; exit 1; }
[[ "$(dpkg-deb -f "$package" Version)" == "$version" ]]
[[ "$(dpkg-deb -f "$package" Architecture)" == amd64 ]]
base="$HOME/.local/opt/cc-switch"
mkdir -p "$base" "$HOME/.local/bin" "$HOME/.local/share/applications"
target="$base/$version-uos"
if [[ -e "$target" ]]; then
  echo "Installation already exists: $target (not overwriting)" >&2
  exit 1
fi
dpkg-deb -x "$package" "$target"
ln -sfn "$version-uos" "$base/current"
cat > "$HOME/.local/bin/cc-switch" <<'LAUNCHER'
#!/usr/bin/env bash
set -u
if [[ "${1:-}" == --version ]]; then
  printf 'CC Switch 3.20.3 (UOS 20 compatibility build)\n'
  exit 0
fi
binary="$HOME/.local/opt/cc-switch/current/usr/bin/cc-switch"
focus_running() {
  local pid w geometry width height
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    if command -v xdotool >/dev/null 2>&1; then
      for w in $(xdotool search --pid "$pid" 2>/dev/null); do
        geometry=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null) || continue
        width=$(printf '%s\n' "$geometry" | sed -n 's/^WIDTH=//p')
        height=$(printf '%s\n' "$geometry" | sed -n 's/^HEIGHT=//p')
        if [[ "${width:-0}" -ge 400 && "${height:-0}" -ge 300 ]]; then
          xdotool windowmap "$w" windowactivate "$w" >/dev/null 2>&1 || true
          break
        fi
      done
    fi
    return 0
  done < <(pgrep -u "$(id -u)" -x cc-switch || true)
  return 1
}
focus_running && exit 0
state="$HOME/.cache/cc-switch-launcher"
mkdir -p "$state"
chmod 700 "$state"
exec 9>"$state/instance.lock"
if ! flock -n 9; then
  focus_running || true
  exit 0
fi
umask 077
"$binary" "$@" 9>&- >>"$state/launch.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true' TERM INT
wait "$pid"
exit $?
LAUNCHER
chmod +x "$HOME/.local/bin/cc-switch"
cat > "$HOME/.local/share/applications/cc-switch.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=CC Switch
Name[zh_CN]=CC Switch
Comment=CC Switch $version — UOS 20 compatibility build
Exec="$HOME/.local/bin/cc-switch" %U
Icon=$target/usr/share/icons/hicolor/128x128/apps/cc-switch.png
Terminal=false
Categories=Development;Utility;
StartupWMClass=cc-switch
DESKTOP
desktop-file-validate "$HOME/.local/share/applications/cc-switch.desktop"
update-desktop-database "$HOME/.local/share/applications" || true
desktop="$(xdg-user-dir DESKTOP)"
if [[ -d "$desktop" && ! -e "$desktop/CC Switch.desktop" ]]; then
  cp "$HOME/.local/share/applications/cc-switch.desktop" "$desktop/CC Switch.desktop"
  chmod +x "$desktop/CC Switch.desktop"
fi
printf 'Installed for current user: %s\n' "$target"
"$HOME/.local/bin/cc-switch" --version
