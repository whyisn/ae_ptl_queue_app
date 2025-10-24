# Proses Rilis AE•PTL
1) Bump versi di `pubspec.yaml`
2) Commit + push, tag:  git tag v1.0.0 && git push origin v1.0.0
3) CI: build Web (Vercel) & build APK (GitHub Releases)
4) Update tabel `app_meta` di Supabase (latest/min/download_url/changelog)
5) Verifikasi: Web live & APK terpasang
