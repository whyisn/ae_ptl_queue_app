#!/usr/bin/env bash
set -euxo pipefail

# Install dependensi yang mungkin dibutuhkan
apt-get update && apt-get install -y xz-utils git curl ca-certificates

# Ambil Flutter stable terbaru
git clone https://github.com/flutter/flutter.git -b stable
# Tandai folder flutter sebagai safe.directory agar git tidak protes
git config --global --add safe.directory "$(pwd)/flutter"

export PATH="$PATH:$PWD/flutter/bin"

flutter --version
dart --version

# Enable web & ambil dependency
flutter config --enable-web
flutter pub get
