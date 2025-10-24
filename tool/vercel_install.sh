#!/usr/bin/env bash
set -euxo pipefail

# Pastikan tools ada
if ! command -v xz >/dev/null 2>&1; then
  # Beberapa image Vercel sudah punya xz; kalau tidak ada, install cepat
  apt-get update && apt-get install -y xz-utils
fi

# Unduh Flutter SDK dan export ke PATH
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz"
curl -L "$FLUTTER_URL" | tar -xJ
export PATH="$PATH:$PWD/flutter/bin"

flutter --version
flutter config --enable-web
flutter pub get
