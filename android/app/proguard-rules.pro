# ProGuard/R8 keep rules. CATATAN: minifyEnabled belum diaktifkan di
# build.gradle.kts (release build sekarang TIDAK di-shrink/obfuscate), jadi
# file ini belum benar-benar dipakai. Disiapkan sebagai jaring pengaman kalau
# nanti minifyEnabled diaktifkan (mis. buat memperkecil ukuran APK) - tanpa
# rule ini, R8 pernah dilaporkan menghapus/mengacak class ML Kit & CameraX
# yang dipakai package mobile_scanner (untuk scan barcode), menyebabkan
# kamera gagal dibuka di release build walau lancar di debug.

# ML Kit (Google Barcode Scanning API) - dipakai mobile_scanner.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# CameraX - dipakai mobile_scanner buat akses kamera.
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Google Play Services Dynamite Module loader (tempat model ML Kit di-download).
-keep class com.google.android.gms.dynamite.** { *; }
-dontwarn com.google.android.gms.**
