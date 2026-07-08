import 'package:flutter/foundation.dart';

/// Sinyal global perubahan data. Di-`ping()` setiap ada transaksi
/// (barang masuk/keluar, tambah lokasi) sehingga semua layar yang
/// menampilkan daftar bisa memuat ulang datanya secara otomatis —
/// meski tab-nya sedang tidak terlihat (IndexedStack tetap hidup).
class DataRefresh {
  DataRefresh._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void ping() => notifier.value++;
}
