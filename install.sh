#!/bin/bash
# SPDX-FileCopyrightText: 2026 DaaarQ <DaaarQ@users.noreply.github.com>
# SPDX-FileCopyrightText: 2026 Rob Tagg <rob@tagg.co.uk>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Derived in 2026 by Rob Tagg <rob@tagg.co.uk> from upstream's install.sh at
# commit ecdace15 of https://github.com/DaaarQ/itpp130-linux-driver, and
# substantially rewritten: it builds and tests without root, installs through
# RPM rather than copying files into place, and configures the CUPS queue.
#
# install.sh - build, install and configure the driver on this machine
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ " $* " == *' --help '* || " $* " == *' -h '* ]]; then
  echo "Usage: ./install.sh [munbyn-setup options]"
  echo "Installs distro build dependencies, builds/tests a local RPM, installs it, and configures the printer."
  echo "Run without sudo; it requests sudo only for system changes."
  "$ROOT/munbyn-setup" --help
  exit 0
fi
for arg in "$@"; do
  if [[ $arg == --dry-run ]]; then
    exec "$ROOT/munbyn-setup" "$@"
  fi
done
if (( EUID == 0 )); then echo 'Run ./install.sh as your normal user, without sudo.' >&2; exit 1; fi
if ! command -v dnf >/dev/null; then echo 'This installer requires a Fedora/Nobara system with DNF and CUPS 2.' >&2; exit 1; fi
# Validate all arguments before installing packages.
"$ROOT/munbyn-setup" --validate-only "$@"
DEPENDENCIES=(gcc make rpm-build redhat-rpm-config cups-devel cups cups-filters ghostscript python3)
# A Bluetooth queue is useless without the backend that opens the RFCOMM socket.
for arg in "$@"; do
  if [[ $arg == --bluetooth ]]; then DEPENDENCIES+=(bluez-cups bluez); break; fi
done
sudo dnf install "${DEPENDENCIES[@]}"
OUT=$(mktemp -d /tmp/munbyn-install.XXXXXXXX)
trap 'rm -rf -- "$OUT"' EXIT
"$ROOT/build-rpm.sh" "$OUT"
shopt -s nullglob
PACKAGES=("$OUT"/*.rpm)
BINARY=()
for package in "${PACKAGES[@]}"; do [[ $package == *.src.rpm ]] || BINARY+=("$package"); done
if (( ${#BINARY[@]} != 1 )); then echo 'Expected exactly one binary RPM; stopping.' >&2; exit 1; fi
sudo dnf install "${BINARY[0]}"
sudo /usr/bin/munbyn-setup "$@"
