App manajemen barang (inventory) Flutter + SQLite lokal via sqflite.
Konsep: stok terpusat di gudang pusat, lalu didistribusikan ke lokasi/instansi/UKPD lewat transaksi barang keluar.
Fitur: Splash, Login, Dashboard, Barang Masuk, Barang Keluar (distribusi + upload berita acara), Stok Keseluruhan, Wilayah/UKPD, Riwayat, Profil.
Navigasi: BottomNavigationBar 4 tab (Home, Barang, Riwayat, Profil).
ID barang auto-generate (BRG-0001). Berita acara: upload file/foto, simpan path di DB. Password: hash, bukan plaintext.
Struktur: lib/database_helper.dart, lib/models/, lib/screens/.
