#!/usr/bin/env bash
# Buduje aplikację i uruchamia testy jednostkowe na symulatorze iPhone'a i iPada.
#
# Zmienne (opcjonalne):
#   IPHONE_DESTINATION  np. "platform=iOS Simulator,name=iPhone 16"
#   IPAD_DESTINATION    np. "platform=iOS Simulator,name=iPad Air 11-inch (M2)"
#   STRICT=0            nie traktuj ostrzeżeń jako błędów
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="KorepetytorAI.xcodeproj"
SCHEME="KorepetytorAI"
STRICT="${STRICT:-1}"
LOG_DIR="build/logs"
LOG_FILE="$LOG_DIR/test.log"

# Pierwszy dostępny symulator danego typu (iPhone / iPad), jako "id=<UDID>".
pick_simulator() {
  local udid
  udid="$(xcrun simctl list devices available \
    | sed -nE "s/^[[:space:]]+$1.*\(([0-9A-F-]{36})\).*/\1/p" \
    | head -n 1)"
  if [[ -z "$udid" ]]; then
    echo "Brak dostępnego symulatora: $1. Zainstaluj go w Xcode (Settings > Components)." >&2
    exit 1
  fi
  echo "id=$udid"
}

IPHONE_DESTINATION="${IPHONE_DESTINATION:-$(pick_simulator iPhone)}"
IPAD_DESTINATION="${IPAD_DESTINATION:-$(pick_simulator iPad)}"

echo "iPhone: $IPHONE_DESTINATION"
echo "iPad:   $IPAD_DESTINATION"

STRICT_SETTINGS=()
if [[ "$STRICT" == "1" ]]; then
  STRICT_SETTINGS=(SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES)
fi

mkdir -p "$LOG_DIR"

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$IPHONE_DESTINATION" \
  -destination "$IPAD_DESTINATION" \
  -resultBundlePath "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  "${STRICT_SETTINGS[@]}" \
  2>&1 | tee "$LOG_FILE"

# Ostrzeżenia spoza kompilatora Swift (np. katalog zasobów, ustawienia projektu).
if [[ "$STRICT" == "1" ]]; then
  if grep -E "(^|[[:space:]])warning: " "$LOG_FILE" | grep -v "Metadata extraction skipped" | sort -u | grep .; then
    echo "Kompilacja zgłosiła ostrzeżenia (lista powyżej)." >&2
    exit 1
  fi
fi

echo "Testy przeszły na iPhonie i iPadzie, bez ostrzeżeń."
