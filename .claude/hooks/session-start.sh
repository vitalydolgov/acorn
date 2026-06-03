#!/usr/bin/env bash
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
if command -v swift >/dev/null 2>&1; then swift --version; exit 0; fi

# Direct download from swift.org (swiftly's Apple CDN init endpoint is blocked).
SWIFT_VERSION="6.3"
SWIFT_RELEASE="swift-${SWIFT_VERSION}-RELEASE"
. /etc/os-release
PLATFORM_PATH="ubuntu${VERSION_ID//.}"   # e.g. ubuntu2404  (used in URL path)
PLATFORM_FILE="ubuntu${VERSION_ID}"      # e.g. ubuntu24.04 (used in filename)
TARBALL="${SWIFT_RELEASE}-${PLATFORM_FILE}.tar.gz"
URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${PLATFORM_PATH}/${SWIFT_RELEASE}/${TARBALL}"
INSTALL_DIR="/opt/swift/${SWIFT_RELEASE}"

if [ -x "${INSTALL_DIR}/usr/bin/swift" ]; then
    echo "Swift ${SWIFT_VERSION} already extracted, skipping download."
else
    mkdir -p "${INSTALL_DIR}"
    echo "Downloading Swift ${SWIFT_VERSION}..."
    curl -fSL "${URL}" -o /tmp/swift.tar.gz
    tar -xzf /tmp/swift.tar.gz -C "${INSTALL_DIR}" --strip-components=1
    rm /tmp/swift.tar.gz
fi
ln -sf "${INSTALL_DIR}/usr/bin/swift" /usr/local/bin/swift
swift --version
