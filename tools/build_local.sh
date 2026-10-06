#!/usr/bin/env bash
# Локальная сборка релизов.
#  - apk (по умолчанию): раздельные APK под каждую архитектуру
#    (vysh.<версия>.<abi>.apk, ~20-24 МБ каждый);
#  - apk-universal: один APK со всеми тремя ABI (в ~3 раза больше).
#  GRADLE_OPTS глушит JDK-предупреждение «restricted method in
#  java.lang.System» от Gradle 9 на новых Java.
#  flutter build копирует APK из gradle-выхлопа под стандартным именем
#  (app-<abi>-release.apk), поэтому переименовываем сами.
set -euo pipefail
export GRADLE_OPTS="--enable-native-access=ALL-UNNAMED${GRADLE_OPTS:+ $GRADLE_OPTS}"
build_date="$(date '+%d.%m.%y %H:%M:%S')"
target="${1:-apk}"
shift || true
case "$target" in
  apk)
    flutter build apk --split-per-abi --release \
      --dart-define="BUILD_DATE=$build_date" "$@"
    ;;
  apk-universal)
    flutter build apk --release --dart-define="BUILD_DATE=$build_date" "$@"
    ;;
  linux) flutter build linux --release --dart-define="BUILD_DATE=$build_date" "$@" ;;
  windows) flutter build windows --release --dart-define="BUILD_DATE=$build_date" "$@" ;;
  *) echo "Usage: $0 {apk|apk-universal|linux|windows} [flutter build args]" >&2; exit 2 ;;
esac

# Имена вида vysh.<версия>.<abi>.apk задаёт gradle (build.gradle.kts);
# их же кладём рядом со стандартными, чтобы не искать по папкам.
if [[ "$target" == "apk" || "$target" == "apk-universal" ]]; then
  out=build/app/outputs/flutter-apk
  for f in build/app/outputs/apk/release/vysh.*.apk; do
    [[ -e "$f" ]] || continue
    cp "$f" "$out/"
  done
fi
