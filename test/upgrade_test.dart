// Reproduksi bug dashboard saat upgrade DB lama (pra-kembali) ke skema baru.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stokbarang/database_helper.dart';

void main() {
  late Directory tmpDir;
  late String dbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('stokbarang_upgrade');
    dbPath = '${tmpDir.path}/old.db';
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('Upgrade DB lama (v3) → dashboard & riwayat tetap jalan', () async {
    // 1. Buat DB "lama" versi 3: ada foto_path & lokasi, TANPA transaksi_kembali.
    final old = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 3),
    );
    await old.execute('''
      CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT,
        password_hash TEXT, nama_lengkap TEXT, role TEXT)''');
    await old.execute('''
      CREATE TABLE barang (id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_barang TEXT, nama TEXT, merek TEXT, tipe TEXT, satuan TEXT,
        stok_pusat INTEGER, foto_path TEXT)''');
    await old.execute('''
      CREATE TABLE lokasi (id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_lokasi TEXT, nama TEXT, alamat TEXT)''');
    await old.execute('''
      CREATE TABLE stok_lokasi (id INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id INTEGER, lokasi_id INTEGER, jumlah INTEGER)''');
    await old.execute('''
      CREATE TABLE transaksi_masuk (id INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id INTEGER, jumlah INTEGER, keterangan TEXT, user_id INTEGER,
        tanggal TEXT)''');
    await old.execute('''
      CREATE TABLE transaksi_keluar (id INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id INTEGER, lokasi_id INTEGER, jumlah INTEGER,
        berita_acara_path TEXT, keterangan TEXT, user_id INTEGER,
        tanggal TEXT)''');
    // Data contoh seperti di HP.
    await old.insert('barang', {
      'kode_barang': 'BRG-0001',
      'nama': 'Kertas',
      'satuan': 'rim',
      'stok_pusat': 50,
    });
    await old.insert('transaksi_masuk', {
      'barang_id': 1,
      'jumlah': 50,
      'tanggal': DateTime.now().toIso8601String(),
    });
    await old.close();

    // 2. Buka lewat DatabaseHelper → memicu onUpgrade v3 → v4.
    DatabaseHelper.debugDatabasePath = dbPath;
    final db = DatabaseHelper.instance;

    // 3. Panggil yang dipakai Dashboard — tidak boleh throw.
    final stats = await db.getDashboardStats(sejak: DateTime(2000));
    expect(stats.totalMasuk, 50);
    expect(stats.totalKembali, 0);

    final riwayat = await db.getRiwayat(limit: 5);
    expect(riwayat.length, 1);
  });
}
