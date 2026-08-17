# Migrasi database Kasir Pro

Database sebenarnya (Supabase project `gyibrbxvffqfxveckhcp`) adalah sumber
kebenaran yang berjalan — folder ini adalah **riwayat/version control**-nya
di git, karena PostgREST/Supabase tidak otomatis menyimpan riwayat migrasi
ke repo.

## Riwayat

`20260817_00` sampai `20260817_03` adalah **snapshot baseline**: rekonstruksi
skema live database pada 17 Agustus 2026, dibuat karena 45 migrasi sebelumnya
diterapkan langsung ke production tanpa pernah disimpan sebagai file di sini.
Bukan urutan histori asli — ini potret satu waktu.

## Mulai dari sini: SETIAP migrasi baru WAJIB disimpan sebagai file

Kalau menerapkan perubahan skema (tabel/fungsi/trigger/RLS baru) ke database
production, simpan juga SQL-nya sebagai file baru di folder ini dengan nama:

```
YYYYMMDD_NN_deskripsi-singkat.sql
```

`NN` adalah urutan dalam hari yang sama kalau lebih dari satu migrasi.
Jangan menimpa file lama — migrasi baru selalu file baru.
