#!/usr/bin/env bash
set -e

# 1) Download & add Flutter to PATH
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz"
curl -L "$FLUTTER_URL" | tar -xJ
export PATH="$PATH:$PWD/flutter/bin"

# 2) Enable web & install deps
flutter --version
flutter config --enable-web
flutter pub get
