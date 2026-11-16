#!/usr/bin/env bash
# Buduje aplikację i uruchamia testy jednostkowe na symulatorze iPhone'a i iPada.
# Działa z bash 3.2 (domyślny na macOS).
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
MIN_IOS_MAJOR=18
LOG_DIR="build/logs"
LOG_FILE="$LOG_DIR/test.log"

# Najnowszy dostępny symulator danego typu (iPhone / iPad) z iOS >= 18, jako "id=<UDID>".
pick_simulator() {
  local udid
  udid="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, re, sys
want, minimum = sys.argv[1], int(sys.argv[2])
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match or int(match[1]) < minimum:
        continue
    version = (int(match[1]), int(match[2]))
    for device in devices:
        if device["name"].startswith(want) and (best is None or version > best[0]):
            best = (version, device["udid"])
print(best[1] if best else "")
' "$1" "$MIN_IOS_MAJOR")"
  if [[ -z "$udid" ]]; then
    echo "Brak symulatora $1 z iOS $MIN_IOS_MAJOR lub nowszym. Zainstaluj go w Xcode (Settings > Components)." >&2
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
  STRICT_SETTINGS=(SWIFT_SUPPRESS_WARNINGS=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES)
fi

mkdir -p "$LOG_DIR"

# ${tablica[@]+...}: pusta tablica przy `set -u` w bash 3.2.
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$IPHONE_DESTINATION" \
  -destination "$IPAD_DESTINATION" \
  -resultBundlePath "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  ${STRICT_SETTINGS[@]+"${STRICT_SETTINGS[@]}"} \
  2>&1 | tee "$LOG_FILE"

# Ostrzeżenia z naszego kodu i zasobów, których nie łapie SWIFT_TREAT_WARNINGS_AS_ERRORS
# (katalogi zasobów, String Catalog, Info.plist). Narzędzia systemowe są pomijane.
if [[ "$STRICT" == "1" ]]; then
  if grep -E "\.(swift|xcassets|xcstrings|plist|entitlements|xcconfig|pbxproj)(:[0-9]+)*: warning: " "$LOG_FILE" \
      | sort -u | grep .; then
    echo "Kompilacja zgłosiła ostrzeżenia (lista powyżej)." >&2
    exit 1
  fi
fi

echo "Testy przeszły na iPhonie i iPadzie, bez ostrzeżeń."
