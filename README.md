# Kasir Pro

Aplikasi Kasir/POS untuk UMKM Indonesia. Flutter (Riverpod + GoRouter) + Supabase.

## Setup

```bash
flutter pub get
flutter run
```

Build APK dilakukan lewat GitHub Actions/Codespaces (device kerja utama tidak bisa build Flutter langsung).

## Struktur

- `lib/core` — theme (dark mode + neon green), router, konfigurasi Supabase, provider sesi
- `lib/models` — model data (Store, Staff, Product, Transaction, dst.)
- `lib/features` — satu folder per fitur: auth, pos, shift, products, dashboard, reports, history, printer
- `lib/shared/widgets` — AppShell (sidebar untuk tablet/desktop, bottom nav untuk HP)

## Supabase

Project: `gyibrbxvffqfxveckhcp` ("Project kasir") — **terpisah total** dari project NexaPay/Ppob (`ekbescwqymtqvbjmxxhu`). Jangan pernah ditukar.

8 tabel: `stores`, `staff`, `categories`, `products`, `stock_movements`, `transactions`, `transaction_items`, `shifts`.

RPC penting: `void_or_refund_transaction(p_transaction_id, p_new_status, p_reason)` — dipakai untuk void/refund transaksi secara atomic (cek role admin/owner, kembalikan stok, catat stock_movements, update status).

## Role & Akses

- **Kasir**: POS, Riwayat, Shift, Printer
- **Admin/Owner**: + Dashboard, Produk, Laporan, Void/Refund transaksi

Akun staff dibuat manual oleh owner/admin lewat Supabase Dashboard (Authentication → Add User), lalu di-link ke tabel `staff`. Tidak ada self-registration.

## Fitur yang sudah jalan

- POS: grid produk realtime, keranjang, diskon per-item & per-transaksi
- Shift kasir: buka/tutup + hitung selisih kas otomatis
- Manajemen produk (CRUD)
- Dashboard ringkasan harian
- Laporan grafik 7 hari + laba kotor
- Riwayat transaksi + void/refund (admin/owner)
- Cetak struk via printer Bluetooth ESC/POS (58mm/80mm)

## Roadmap (belum dibangun)

- Upload foto produk ke Supabase Storage
- Export laporan ke PDF/Excel
- Notifikasi push stok menipis (FCM)
- Mode offline (Hive queue + sync)
- Versi web
