# StokBarang

Aplikasi Flutter untuk mengelola stok barang dan mendistribusikannya ke sejumlah
Wilayah/UKPD (studi kasus Jakarta Barat). Semua data disimpan lokal di device
memakai SQLite, jadi aplikasi tetap jalan tanpa server maupun koneksi internet.

## Fitur

- **Barang masuk** — catat penambahan stok ke gudang pusat. Barang dengan nama,
  merek, dan tipe yang sama akan digabung stoknya; barang baru otomatis dapat
  kode berurutan (`BRG-0001`, `BRG-0002`, ...).
- **Barang keluar** — distribusi barang dari gudang pusat ke sebuah Wilayah/UKPD.
  Stok divalidasi dulu, dan bisa dilampiri berita acara (foto/PDF).
- **Barang kembali** — retur barang dari lokasi kembali ke gudang pusat.
- **Stok per lokasi** — lihat barang apa saja dan berapa jumlahnya di tiap UKPD.
- **Riwayat** — semua transaksi masuk, keluar, dan kembali dalam satu daftar,
  bisa difilter per tanggal.
- **Dashboard** — ringkasan jumlah jenis barang, total stok pusat, serta total
  masuk/keluar/kembali pada periode berjalan.
- **Login & user** — autentikasi sederhana dengan password di-hash SHA-256
  (tidak pernah disimpan plaintext), plus ganti password.

## Struktur navigasi

Aplikasi punya empat tab utama: **Dashboard**, **Barang**, **Riwayat**, dan
**Profil**.

## Teknologi

- **Flutter** (Dart SDK ≥ 3.11.4) dengan Material Design.
- **sqflite** — database SQLite lokal.
- **crypto** — hashing password.
- **shared_preferences** — menyimpan session login.
- **image_picker / file_picker** — ambil foto barang & berkas berita acara.
- **path_provider / open_filex** — simpan dan buka file berita acara.

## Menjalankan

```bash
flutter pub get
flutter run
```

Database SQLite dibuat otomatis di device saat aplikasi pertama kali dijalankan —
tidak perlu menyalin file DB dari mana pun. Saat pertama dibuat, DB sudah
ter-*seed* dengan:

- User default `admin` / `admin123`
- 31 Wilayah/UKPD bawaan sebagai tujuan distribusi

> Catatan: karena database bersifat lokal per device, data barang/transaksi tidak
> ikut berpindah antar-HP. Setiap instalasi mulai dari data awal yang sama.

Panduan setup lebih lengkap ada di [DOC.md](DOC.md).

## Struktur proyek

```
lib/
├── main.dart              # Entry point aplikasi
├── app_theme.dart         # Tema Material
├── database_helper.dart   # Singleton SQLite: skema, migrasi, semua query
├── models/                # Barang, Lokasi, TransaksiMasuk/Keluar
├── screens/               # Halaman UI (login, dashboard, barang, riwayat, dll.)
├── services/              # Session, penyimpanan file, sinyal refresh data
├── widgets/               # Komponen UI yang dipakai ulang
└── utils/                 # Helper format
```

### Catatan soal database

Seluruh akses data lewat `DatabaseHelper` (singleton). Beberapa hal yang perlu
diketahui:

- Operasi yang menyentuh lebih dari satu tabel (barang masuk/keluar/kembali)
  dibungkus dalam satu transaction SQLite supaya konsisten (atomic).
- Foreign key di-*enforce* (`PRAGMA foreign_keys = ON`).
- Skema punya versi (saat ini v4) dengan jalur migrasi, jadi data lama tetap
  terpakai ketika aplikasi di-update.

## Testing

```bash
flutter test
```

Test dijalankan di host memakai `sqflite_common_ffi` (tanpa emulator). Ada
pengujian alur data (`flow_test.dart`), migrasi skema (`upgrade_test.dart`), dan
widget (`widget_test.dart`).
