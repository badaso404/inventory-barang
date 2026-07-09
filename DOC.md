1. Pastikan Flutter terpasang (sekali saja)

Install Flutter channel stable — punyamu 3.41.6 (Dart SDK 3.11.4). Amannya pakai versi sama atau lebih baru.
Cek kesiapan:

flutter doctor
Semua yang dipakai (Android toolchain / Xcode kalau iOS) harus ✓. 2. Clone repo

git clone https://github.com/badaso404/inventory-barang.git
cd inventory-barang 3. Ambil dependency

flutter pub get 4. Jalankan (dengan HP/emulator tersambung)

flutter run
Atau tinggal tekan Run di VS Code / Android Studio.

5. Login

Database SQLite dibuat otomatis di device saat pertama kali app jalan — tidak perlu menyalin DB dari kamu.
Otomatis ter-seed user admin / admin123 dan 31 UKPD bawaan.
Hal penting
Tidak perlu memindahkan file database atau data — tiap device punya DB lokal sendiri yang dibuat dari awal. Jadi barang/transaksi yang ada di HP-mu tidak ikut; punya temanmu mulai kosong (wajar untuk SQLite lokal).
Versi Flutter: kalau flutter pub get gagal dengan pesan soal SDK (requires Dart >= 3.11.4), berarti Flutter temanmu terlalu lama → suruh update: flutter upgrade.
Kalau target iOS dan ada error CocoaPods: cd ios && pod install lalu jalankan lagi (biasanya otomatis).
Izin kamera/galeri/file (untuk foto barang & berita acara) sudah dikonfigurasi di repo, jadi tinggal jalan.
Kalau temanmu mentok di salah satu langkah (paling sering: flutter doctor belum ✓ atau versi Flutter beda), kirim pesan error-nya — biasanya gampang dibereskan.
