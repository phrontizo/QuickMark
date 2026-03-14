#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: bump-version.sh <version>}"

# Validate format: X.Y or X.Y.Z
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Error: Version must be in format X.Y or X.Y.Z (e.g., 1.1 or 1.1.0)"
  exit 1
fi

PLISTS=(
  "QuickMark/Info.plist"
  "Markdown/Info.plist"
  "DrawIO/Info.plist"
  "Structured/Info.plist"
)

# Update marketing version
for plist in "${PLISTS[@]}"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
done

# Build number: total git commits + 1 (for the upcoming version commit)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo "0")
BUILD=$((BUILD + 1))

for plist in "${PLISTS[@]}"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$plist"
done

echo "Version: $VERSION (build $BUILD)"
