#!/usr/bin/env bash
set -euo pipefail
build_date="$(date '+%d.%m.%y %H:%M:%S')"
target="${1:-apk}"
shift || true
case "$target" in
  apk) flutter build apk --release --dart-define="BUILD_DATE=$build_date" "$@" ;;
  linux) flutter build linux --release --dart-define="BUILD_DATE=$build_date" "$@" ;;
  windows) flutter build windows --release --dart-define="BUILD_DATE=$build_date" "$@" ;;
  *) echo "Usage: $0 {apk|linux|windows} [flutter build args]" >&2; exit 2 ;;
esac
