# Kasir Pro

Aplikasi Kasir/POS untuk UMKM Indonesia. Flutter (Riverpod + GoRouter) + Supabase.

> **Catatan:** README ini di-update 22 Agustus 2026 supaya sinkron dengan kondisi database & kode aktual (sebelumnya ketinggalan jauh — masih bilang "8 tabel" padahal sudah 36).

## Setup

```bash
flutter pub get
flutter run
```

Build APK dilakukan lewat GitHub Actions (workflow `Build APK`, trigger manual via `workflow_dispatch`) — device kerja utama (Termux di Android) tidak bisa build Flutter langsung. CI (`Flutter CI` — analyze + test) juga trigger manual, hasil gagal otomatis diposting sebagai GitHub Issue baru (raw job log GitHub Actions sekarang di-redirect ke Azure Blob Storage yang tidak bisa diakses tool otomatis).

## Struktur

- `lib/core` — theme (dark mode + neon green), router, konfigurasi Supabase, provider sesi, global error handler
- `lib/models` — model data (Store, Staff, Product, Transaction, Customer, Supplier, Purchase, Promotion, Device, ApprovalRequest, dst.)
- `lib/features` — satu folder per modul (lihat daftar fitur di bawah)
- `lib/shared/widgets` — AppShell (sidebar untuk tablet/desktop, bottom nav untuk HP)

## Supabase

Project: `gyibrbxvffqfxveckhcp` ("Project kasir") — **terpisah total** dari project NexaPay/Ppob (`ekbescwqymtqvbjmxxhu`). Jangan pernah ditukar.

**36 tabel**, dikelompokkan:
- **POS inti**: `stores`, `staff`, `categories`, `products`, `transactions`, `transaction_items`, `transaction_payments`, `shifts`
- **Cash management**: `cash_movements`, `expenses`
- **Inventory**: `stock_movements`, `stock_opnames`, `stock_opname_items`, `warehouses`, `warehouse_stock`, `stock_transfers`, `stock_transfer_items`
- **Purchasing**: `suppliers`, `purchases`, `purchase_items`, `purchase_payments`
- **Customer/loyalty**: `customers`, `customer_point_ledger`
- **Promo**: `promotions`, `promotion_products`, `promotion_categories`
- **Approval workflow**: `approval_requests`
- **Device & offline**: `devices`, `offline_sync_queue`
- **Accounting**: `accounting_accounts`, `accounting_journals`, `accounting_journal_lines`
- **Lainnya**: `held_carts` (hold/resume transaksi), `qris_payments` (QRIS dinamis), `audit_logs`, `refunds`, `refund_items`

Semua tabel RLS-enabled. Operasi sensitif (checkout, shift, refund, stock, dll) lewat RPC `SECURITY DEFINER` yang **masing-masing memvalidasi otorisasi secara internal** (`auth.uid()` dicocokkan ke `staff`, `is_store_staff()`/`is_store_admin()`). Supabase security advisor akan selalu menampilkan warning generik "SECURITY DEFINER function executable by authenticated" untuk hampir semua RPC ini — itu **peringatan blanket, bukan indikasi bug**; yang penting adalah isi function-nya sudah tervalidasi manual (audit terakhir: 22 Agustus 2026, 3 fungsi laporan — `sales_summary`, `payment_summary`, `low_stock_report` — ditemukan tanpa validasi store dan sudah diperbaiki).

RPC penting: `checkout_transaction` (atomic checkout + idempotency key + split payment), `open_shift`/`close_shift`, `void_or_refund_transaction`, `refund_transaction_items` (partial refund), `receive_purchase`, `apply_stock_opname`, `transfer_stock`, `create_balanced_journal`, `set_staff_pin`/`verify_staff_pin`, `request_approval`/`decide_approval`, `finalize_qris_payment` (dipanggil webhook Midtrans, bukan client).

## Edge Functions

- `create-qris-payment` — generate QRIS dinamis via Midtrans Core API (`verify_jwt: true`)
- `midtrans-webhook` — terima notifikasi pembayaran Midtrans, verifikasi signature, finalisasi transaksi (`verify_jwt: false`, keamanan dari signature Midtrans sendiri bukan Supabase JWT)
- `h2h-sync-products` — tarik pricelist H2H.id (pulsa/paket_data/pln), terapkan margin, upsert ke `ppob_products`. Cuma platform admin (`verify_jwt: true`).
- `h2h-order` — proses order pulsa/PPOB: reserve saldo toko (RPC) → panggil H2H.id → finalize (RPC). Dipanggil dari fitur Pulsa & Digital.
- `h2h-status-check` — polling status order yang masih `pending` (H2H async, sering balas pending dulu).

**QRIS dinamis butuh setup manual**: `supabase secrets set MIDTRANS_SERVER_KEY=... --project-ref gyibrbxvffqfxveckhcp`, lalu daftarkan webhook URL di dashboard Midtrans. Tanpa ini, QRIS statis (upload 1 gambar QRIS, konfirmasi manual) tetap jalan sebagai fallback.

**Fitur Pulsa & Digital (H2H.id) butuh setup manual**: `supabase secrets set H2H_MEMBER_ID=... H2H_PIN=... H2H_PASSWORD=... --project-ref gyibrbxvffqfxveckhcp` (kredensial sama dengan akun H2H yang dipakai backend NexaPay/ppob-app). Setelah itu jalankan `h2h-sync-products` sekali (lewat tombol di app atau manual invoke) buat isi katalog awal.

## Role & Akses

- **Kasir**: POS, Riwayat, Shift, Kitchen Display, Printer, Pulsa & Digital (jual saja, tidak bisa top up saldo)
- **Admin/Owner**: + Dashboard, Produk, Inventory, Pelanggan, Promo, Laporan, Accounting, Approval, Device Management, void/refund, Top Up Saldo Pulsa

Akun staff dibuat manual oleh owner/admin lewat Supabase Dashboard (Authentication → Add User), lalu di-link ke tabel `staff`. Tidak ada self-registration. Kasir juga bisa dikunci dengan PIN 4-6 digit (lock screen otomatis saat app kembali dari background).

## Fitur yang sudah jalan

- **POS**: grid produk realtime, keranjang, diskon per-item & per-transaksi, split payment, hold/resume transaksi, scan barcode
- **Shift kasir**: buka/tutup + cash in/out/expense + hitung selisih kas otomatis
- **Inventory**: supplier, terima barang (restock), stock opname, transfer antar-gudang
- **Manajemen produk**: CRUD + scan barcode untuk SKU
- **Customer/loyalty**: CRUD pelanggan + poin
- **Promo/voucher**: persen/nominal + kode redeem
- **Dashboard & Laporan**: ringkasan harian, grafik 7 hari, laba kotor, export PDF/Excel
- **Accounting**: chart of accounts, jurnal otomatis dari penjualan + jurnal manual, laporan Laba-Rugi
- **Riwayat transaksi**: void, partial refund (per-item)
- **Approval workflow**: ajukan & setujui/tolak aksi sensitif
- **Device management**: registrasi & revoke akses device
- **Kitchen Display**: status pesanan per-item (pending/preparing/ready/served) untuk F&B
- **QRIS**: statis (1 gambar, konfirmasi manual) dan dinamis (Midtrans, auto-verifikasi via webhook)
- **Cetak struk**: printer Bluetooth ESC/POS (58mm/80mm) + share struk digital (WhatsApp/dll)
- **PIN lock**: kunci layar per-kasir, reset via verifikasi password akun
- **Audit log**: semua perubahan sensitif (harga, status transaksi, role staff, shift) tercatat otomatis
- **Offline queue**: infrastruktur sinkronisasi (sqflite lokal + `offline_sync_queue`) — **status fungsional end-to-end belum tervalidasi penuh**
- **Pulsa & Digital** (baru, 24 Agu 2026): jual pulsa/paket data/token PLN via H2H.id, menu terpisah dari POS. Saldo prepaid per toko (harus top up dulu), katalog + margin diatur terpusat oleh platform admin. Order async (bisa `pending` dulu, diselesaikan lewat polling status).

## Belum ada / belum lengkap

- QRIS dinamis butuh kredensial Midtrans dari pemilik (belum diisi)
- Leaked Password Protection di Supabase Auth masih OFF (toggle manual di dashboard, bukan lewat kode)
- Belum ada automated widget/integration test (baru unit test dasar: `CartState`, `Formatters`)
- Belum pernah diuji dengan volume transaksi production (database saat ini masih sangat kecil)
- Versi web belum dibangun
