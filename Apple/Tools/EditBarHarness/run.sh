#!/bin/zsh
# Builds the harness for the simulator and launches it on a throwaway
# "Edit Bar Harness" iPhone, created on first run.
set -euo pipefail

cd "$(dirname "$0")"
DEVICE_NAME="Edit Bar Harness"
APP_DIR="build/EditBarHarness.app"

SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
xcrun --sdk iphonesimulator swiftc -parse-as-library -swift-version 6 \
    -target arm64-apple-ios26.0-simulator -sdk "$SDK_PATH" \
    Sources/*.swift -o "$APP_DIR/EditBarHarness"
cp Info.plist "$APP_DIR/Info.plist"
codesign -s - --force "$APP_DIR" >/dev/null

DEVICE_ID="$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
if [[ -z "$DEVICE_ID" ]]; then
    # Newest first; a runtime without iPhone 17 support refuses the device.
    for RUNTIME in $(xcrun simctl list runtimes available | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | sort -ru); do
        DEVICE_ID="$(xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$RUNTIME" 2>/dev/null)" && break
    done
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl install "$DEVICE_ID" "$APP_DIR"
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.katagaki.EditBarHarness >/dev/null
echo "$DEVICE_ID"
