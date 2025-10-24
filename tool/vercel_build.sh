#!/usr/bin/env bash
set -euxo pipefail

export PATH="$PATH:$PWD/flutter/bin"

# Pastikan ENV tersedia
: "${SUPABASE_URL:?Missing SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY}"

# Build Flutter Web
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Verifikasi hasil build — kalau gagal, hentikan agar Vercel tidak “sukses kosong”
test -f build/web/index.html
ls -la build/web
