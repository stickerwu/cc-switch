#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Optional build-only sysroot. Never replace the host's runtime libraries.
ENV_FILE="${CC_SWITCH_BUILD_ENV:-$HOME/.cache/cc-switch-build/env.sh}"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
elif [[ -n "${CC_SWITCH_BUILD_ENV:-}" ]]; then
  echo "Missing requested build environment: $ENV_FILE" >&2
  exit 1
fi
for tool in node pnpm cargo pkg-config dpkg-deb readelf desktop-file-validate; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool (see UOS-BUILD.md)" >&2; exit 1; }
done
pkg-config --modversion gtk+-3.0 webkit2gtk-4.0 ayatana-appindicator3-0.1
pnpm install --frozen-lockfile
pnpm typecheck
pnpm tauri build --bundles deb -- --locked
./scripts/package-uos-deb.sh
