#!/usr/bin/env bash
# Compila o RetroFront para Linux usando as dependencias instaladas via
# Homebrew (linuxbrew). Uso: ./build_linux.sh [debug|release]
set -euo pipefail

BREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"

if [ ! -d "$BREW_PREFIX" ]; then
  echo "Homebrew nao encontrado em $BREW_PREFIX" >&2
  exit 1
fi

export PATH="$BREW_PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:$BREW_PREFIX/lib/pkgconfig:$BREW_PREFIX/opt/xorgproto/share/pkgconfig"
export LIBRARY_PATH="$BREW_PREFIX/lib"
export LD_LIBRARY_PATH="$BREW_PREFIX/lib"

MODE="${1:-release}"
exec flutter build linux --"$MODE"
