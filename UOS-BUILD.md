# CC Switch 3.20.3 — UOS 20 compatibility build

This `uos` branch builds an **amd64 UOS Desktop 20** package, not the official
upstream Tauri 2 Linux package.

- Application source: upstream tag `v3.20.3`, commit
  `d695a2d77fd9081eafd3e9eedcbf2a97b3410928`.
- Port baseline: this repository's UOS commit `07f3fd72`.
- Runtime baseline: glibc 2.28, GTK 3, WebKitGTK **4.0**, libsoup 2.4,
  Ayatana AppIndicator.
- Tauri 1.2.5 / Wry 0.23.4, with the existing vendored WebKit settings fix.
- Frontend and Rust dependency resolutions are committed in both lockfiles.

## Build

### GitHub Actions

Push to `uos`, or dispatch **UOS Deb Build** on that branch. The workflow builds
inside Debian buster to avoid accidentally linking against newer glibc or
WebKitGTK 4.1. It checks TypeScript, runs frontend tests, and builds with frozen
pnpm dependencies and Cargo `--locked`.

The workflow validates the package before publishing a versioned UOS release.
`SHA256SUMS` uses basenames so it can be checked from the download directory:

```bash
sha256sum -c SHA256SUMS
sudo apt install ./CC-Switch-v3.20.3-UOS-amd64.deb
```

### Native UOS / Debian buster

Use Node 22.12 or newer, pnpm 10.12.3, and Rust 1.95 (see
`rust-toolchain.toml`). The build needs a C/C++ compiler, CMake, pkg-config,
OpenSSL development files, GTK 3, WebKitGTK 4.0, libsoup 2.4,
Ayatana AppIndicator, librsvg, libxdo, `dpkg-deb`, `readelf`, and
`desktop-file-validate`. Do not substitute WebKitGTK 4.1.

```bash
./scripts/build-uos-local.sh
```

The script optionally sources `$HOME/.cache/cc-switch-build/env.sh`, or the file
selected by `CC_SWITCH_BUILD_ENV`. On the development UOS machine this supplies
**downloaded and extracted** Debian buster development packages in a user-cache
sysroot. It does not replace any UOS system libraries. On a machine with the
native development packages installed, no environment file is needed. Keep
build-only library search paths out of the application's runtime environment.

Outputs:

- Raw Tauri package: `src-tauri/target/release/bundle/deb/` (or `CARGO_TARGET_DIR`).
- Validated distributable: `release-assets/CC-Switch-v3.20.3-UOS-amd64.deb`.
- `release-assets/SHA256SUMS`, `control.txt`, and `abi-report.txt`.

To validate an existing package without rebuilding:

```bash
./scripts/package-uos-deb.sh /path/to/cc-switch_3.20.3_amd64.deb
```

Validation checks package name/version/architecture, desktop entry, required
runtime dependencies, actual ELF WebKit ABI, absence of build-time RPATH, and
the highest required glibc symbol version (must not exceed 2.28).

## Installation and data safety

Quit any running CC Switch instance through its tray menu before installing or
launching this build. Back up `~/.cc-switch` and any custom app configuration
directory first. Version 3.20.3 migrates the database schema from 13 to 18.
**Do not run 3.17.0 against an already-migrated database.** For rollback, quit the
new version, keep a copy of its data, and restore the pre-upgrade backup.

The `.deb` uses the normal system package manager installation. As an optional
alternative, `./scripts/install-uos-user.sh /path/to/package.deb` extracts into
`~/.local/opt/cc-switch/3.20.3-uos` and creates a current-user launcher/menu entry.
That helper does not use sudo or replace `/usr/bin/cc-switch`; it refuses to
overwrite an existing installation directory. The normal build command does
**not** install or launch anything.

## Compatibility limitations

The UOS port replaces Tauri 2 frontend APIs, tray, dialogs, window APIs and
logging with Tauri 1 equivalents. The new frontend error logger keeps upstream
credential redaction and sends bounded messages to a local backend command.
Logs retain runtime level control and rotation (20 MiB per file, four archives).

The following Tauri 2 plugin integrations are unavailable in this compatibility
build: in-app installation of upstream updates, OS deep-link registration,
window-state persistence, and native single-instance integration. The optional
user launcher prevents duplicate launches through that launcher; directly
starting the packaged executable is not protected by it. Do not run two
instances against the same database. Future upgrades must use a matching UOS
package, not the official upstream Linux binary.

## Verification

The 2026-09-17 verification on UOS Desktop 20 is documented in the commit/release
notes. Runtime smoke tests use a temporary HOME and configuration directory, not
the user's live database. Successful compilation alone is not a runtime test;
check that the main window renders, the log contains no frontend startup errors,
and `ldd` resolves all shared libraries using the host runtime.
