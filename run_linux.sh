#!/usr/bin/env bash
# Roda o RetroFront compilado para Linux. Uso: ./run_linux.sh [release|debug]
set -euo pipefail

BREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
MODE="${1:-release}"
BUNDLE="build/linux/x64/${MODE}/bundle"

export LD_LIBRARY_PATH="${BREW_PREFIX}/lib:${PWD}/${BUNDLE}/lib"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:$BREW_PREFIX/lib/pkgconfig:$BREW_PREFIX/opt/xorgproto/share/pkgconfig"
export LIBRARY_PATH="$BREW_PREFIX/lib"

if [ ! -x "$BUNDLE/retrofront" ]; then
  echo "Binario nao encontrado. Compile antes: ./build_linux.sh $MODE" >&2
  exit 1
fi

exec "$BUNDLE/retrofront" "$@"
