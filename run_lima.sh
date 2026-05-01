#!/bin/zsh

set -euo pipefail

PROJECT_DIR="/Users/a123/a123-dev/lima"
DEVICE_ID="${1:-emulator-5554}"

cd "$PROJECT_DIR"

echo "Stopping stale Flutter/Gradle processes..."
pkill -f "flutter run -d $DEVICE_ID" 2>/dev/null || true
pkill -f "org.gradle.wrapper.GradleWrapperMain.*assembleDebug" 2>/dev/null || true
pkill -f "flutter_tools.snapshot run" 2>/dev/null || true

echo "Launching on $DEVICE_ID..."
exec flutter run --no-pub -d "$DEVICE_ID"
