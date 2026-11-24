#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Error: Missing .env file. Copy .env.example to .env and configure Supabase keys." >&2
  exit 1
fi

set -a
source .env
set +a

echo "==> Building Flutter Android APK (release)..."
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

APK_SOURCE="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK_SOURCE" ]]; then
  echo "Error: Built APK not found at $APK_SOURCE" >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

cp "$APK_SOURCE" "$DIST_DIR/cafe-service.apk"
echo "✓ Android APK copied to: $DIST_DIR/cafe-service.apk"

ls -lh "$DIST_DIR/cafe-service.apk"

# Check if an adb device is connected
if which adb >/dev/null 2>&1; then
  DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" || true)
  if [[ -n "$DEVICES" ]]; then
    echo ""
    echo "Found connected Android device(s):"
    echo "$DEVICES"
    echo "To install directly onto the connected device, run:"
    echo "  adb install -r \"$DIST_DIR/cafe-service.apk\""
  fi
fi
