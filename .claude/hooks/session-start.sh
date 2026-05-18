#!/usr/bin/env bash
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
if command -v swift >/dev/null 2>&1; then swift --version; exit 0; fi

# Fast path: a Swift toolchain is usually pre-extracted under /opt/swift.
# /usr/local/bin is already on PATH, so symlinking the driver there makes
# `swift` available without any network download. The driver dispatches
# subcommands (build/test/package) relative to its resolved real path,
# so a single symlink is enough.
shopt -s nullglob
candidates=(/opt/swift/*/usr/bin/swift)
shopt -u nullglob
if [ ${#candidates[@]} -gt 0 ]; then
    preinstalled=$(printf '%s\n' "${candidates[@]}" | sort -V | tail -1)
    if [ -x "${preinstalled}" ]; then
        ln -sf "${preinstalled}" /usr/local/bin/swift
        swift --version
        exit 0
    fi
fi

# Fallback: install via swiftly. Reuse the pre-installed swiftly binary
# if present; only download it when it's actually missing.
export SWIFTLY_HOME_DIR=/opt/swiftly
export SWIFTLY_BIN_DIR=/usr/local/bin

if ! command -v swiftly >/dev/null 2>&1 && [ ! -x "${SWIFTLY_BIN_DIR}/swiftly" ]; then
    arch=$(uname -m)
    curl -fsSL "https://download.swift.org/swiftly/linux/swiftly-${arch}.tar.gz" -o /tmp/swiftly.tar.gz
    tar -xzf /tmp/swiftly.tar.gz -C /tmp
    /tmp/swiftly init --assume-yes --skip-install --quiet-shell-followup
fi
[ -f "${SWIFTLY_HOME_DIR}/env.sh" ] && . "${SWIFTLY_HOME_DIR}/env.sh"
swiftly install 6.2 --use
swift --version
