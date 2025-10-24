#!/usr/bin/env bash
set -e

# Pastikan flutter di PATH (dari langkah install)
export PATH="$PATH:$PWD/flutter/bin"

# Build Flutter Web pakai env dari Vercel
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
