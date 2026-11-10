#!/bin/bash
# SPDX-FileCopyrightText: 2026 Rob Tagg <rob@tagg.co.uk>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# build-rpm.sh - build the binary and source RPMs without root
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if (( EUID == 0 )); then
  echo 'Build as your normal user, without sudo.' >&2
  exit 1
fi
if (( $# > 1 )); then echo "Usage: $0 [output-directory]" >&2; exit 2; fi
OUT=${1:-"$ROOT/dist"}
mkdir -p -- "$OUT"
OUT=$(cd -- "$OUT" && pwd)
# Atomically allocate a private workspace; never use the upstream package helper.
STAGE=$(mktemp -d /tmp/munbyn-rpmbuild.XXXXXXXX)
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/rpm/SOURCES" "$STAGE/rpm/SPECS" "$STAGE/munbyn-itpp130-driver-1.0.3"
(
  cd "$ROOT"
  sha256sum --check --strict SOURCE-SHA256SUMS
)
cp -a "$ROOT/source/." "$STAGE/munbyn-itpp130-driver-1.0.3/"
install -m 755 "$ROOT/munbyn-setup" "$STAGE/munbyn-itpp130-driver-1.0.3/munbyn-setup"
install -m 644 "$ROOT/README.md" "$STAGE/munbyn-itpp130-driver-1.0.3/README.md"
tar -C "$STAGE" -czf "$STAGE/rpm/SOURCES/munbyn-itpp130-driver-1.0.3.tar.gz" munbyn-itpp130-driver-1.0.3
cp "$ROOT/munbyn-itpp130-driver.spec" "$STAGE/rpm/SPECS/"
rpmbuild -ba --define "_topdir $STAGE/rpm" "$STAGE/rpm/SPECS/munbyn-itpp130-driver.spec"
find "$STAGE/rpm/RPMS" "$STAGE/rpm/SRPMS" -type f -name '*.rpm' -exec install -m 644 '{}' "$OUT/" \;
echo "RPM and source RPM saved in: $OUT"
