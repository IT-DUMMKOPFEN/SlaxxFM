#!/usr/bin/env bash
# Prepares SlaxxFM for a local build (macOS / Linux).
# Usage: ./setup.sh [platforms]   e.g. ./setup.sh macos,android
set -e
PLATFORMS="${1:-windows,linux,macos,android}"
flutter create --org de.itdummkopfen --project-name slaxxfm --platforms="$PLATFORMS" .
flutter pub get
dart run tool/patch_platforms.dart
dart run flutter_launcher_icons || true
echo
echo "Done. Start with:  flutter run -d macos   (or linux / windows / <android device>)"
