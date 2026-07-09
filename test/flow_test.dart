// Uji alur end-to-end data layer:
// login → barang masuk → distribusi keluar → stok berkurang →
// barang muncul di lokasi → riwayat tercatat.
//
// Berjalan di host memakai sqflite_common_ffi (tanpa emulator).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stokbarang/database_helper.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('stokbarang_test');
    DatabaseHelper.debugDatabasePath = '${tmpDir.path}/test.db';
    await databaseFactory.deleteDatabase(DatabaseHelper.debugDatabasePath!);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('Alur lengkap inventory berjalan konsisten', () async {
    final db = DatabaseHelper.instance;

    // 1. Login user default (di-seed onCreate).
    final user = await db.login('admin', 'admin123');
    expect(user, isNotNull, reason: 'user admin default harus bisa login');
    expect(await db.login('admin', 'salah'), isNull);
    final userId = user!['id'] as int;

    // 2. Barang masuk — buat barang baru + kode auto-generate.
    final barangId = await db.barangMasuk(
      nama: 'Kertas A4',
      merek: 'Sinar Dunia',
      tipe: '70gsm',
      jumlah: 100,
      satuan: 'rim',
      userId: userId,
      fotoPath: '/foto_barang/brg_1.jpg',
    );
    var barang = await db.getBarangById(barangId);
    expect(barang!.kodeBarang, 'BRG-0001');
    expect(barang.stokPusat, 100);
    expect(barang.fotoPath, '/foto_barang/brg_1.jpg');

    // Barang masuk lagi dengan nama+merek+tipe sama → stok bertambah, bukan baru.
    final barangId2 = await db.barangMasuk(
      nama: 'Kertas A4',
      merek: 'Sinar Dunia',
      tipe: '70gsm',
      jumlah: 50,
      userId: userId,
    );
    expect(barangId2, barangId, reason: 'harus barang yang sama');
    barang = await db.getBarangById(barangId);
    expect(barang!.stokPusat, 150);
    expect((await db.getStokPusat()).length, 1, reason: 'tetap 1 jenis barang');

    // 3. Distribusi keluar ke lokasi seeded pertama.
    final lokasi = await db.getLokasi();
    expect(lokasi, isNotEmpty);
    final lokasiId = lokasi.first.id!;

    // Tolak bila jumlah melebihi stok pusat.
    final tolak = await db.barangKeluar(
      barangId: barangId,
      lokasiId: lokasiId,
      jumlah: 1000,
      userId: userId,
    );
    expect(tolak, isFalse);
    expect((await db.getBarangById(barangId))!.stokPusat, 150,
        reason: 'stok tak berubah saat ditolak');

    // Distribusi valid.
    final ok = await db.barangKeluar(
      barangId: barangId,
      lokasiId: lokasiId,
      jumlah: 40,
      beritaAcaraPath: '/path/berita_acara/ba_1.jpg',
      keterangan: 'Distribusi triwulan',
      userId: userId,
    );
    expect(ok, isTrue);

    // 4. Stok pusat berkurang.
    expect((await db.getBarangById(barangId))!.stokPusat, 110);

    // 5. Barang muncul di lokasi dengan jumlah benar.
    final diLokasi = await db.getBarangDiLokasi(lokasiId);
    expect(diLokasi.length, 1);
    expect(diLokasi.first['jumlah'], 40);
    expect(diLokasi.first['nama'], 'Kertas A4');
    expect(await db.countBarangDiLokasi(lokasiId), 1);

    // Distribusi lagi ke lokasi yang sama → stok lokasi ter-upsert (akumulasi).
    await db.barangKeluar(
      barangId: barangId,
      lokasiId: lokasiId,
      jumlah: 10,
      userId: userId,
    );
    final diLokasi2 = await db.getBarangDiLokasi(lokasiId);
    expect(diLokasi2.first['jumlah'], 50);
    expect((await db.getBarangById(barangId))!.stokPusat, 100);

    // 6. Riwayat tercatat: 2 masuk + 2 keluar = 4 transaksi.
    final riwayat = await db.getRiwayat();
    expect(riwayat.length, 4);
    expect(riwayat.where((r) => r['tipe'] == 'masuk').length, 2);
    expect(riwayat.where((r) => r['tipe'] == 'keluar').length, 2);

    // Riwayat per barang juga lengkap.
    expect((await db.getRiwayatBarang(barangId)).length, 4);

    // 7. Dashboard stats konsisten.
    final stats = await db.getDashboardStats();
    expect(stats.jenisBarang, 1);
    expect(stats.totalStokPusat, 100);
    expect(stats.totalMasuk, 150); // 100 + 50
    expect(stats.totalKeluar, 50); // 40 + 10

    // 8. Barang kembali (retur) — kebalikan dari keluar.
    // Saat ini: stok pusat 100, stok lokasi 50.

    // Tolak bila melebihi stok di lokasi.
    final tolakKembali = await db.barangKembali(
      barangId: barangId,
      lokasiId: lokasiId,
      jumlah: 999,
      userId: userId,
    );
    expect(tolakKembali, isFalse);
    expect(diLokasi2.first['jumlah'], 50); // snapshot lama tak berubah
    expect((await db.getBarangById(barangId))!.stokPusat, 100);

    // Kembalikan 20 → stok lokasi 30, stok pusat 120.
    final okKembali = await db.barangKembali(
      barangId: barangId,
      lokasiId: lokasiId,
      jumlah: 20,
      keterangan: 'Sisa tidak terpakai',
      userId: userId,
    );
    expect(okKembali, isTrue);
    expect((await db.getBarangById(barangId))!.stokPusat, 120);
    expect((await db.getBarangDiLokasi(lokasiId)).first['jumlah'], 30);

    // Riwayat kini 2 masuk + 2 keluar + 1 kembali = 5.
    final riwayat2 = await db.getRiwayat();
    expect(riwayat2.length, 5);
    expect(riwayat2.where((r) => r['tipe'] == 'kembali').length, 1);
    expect((await db.getRiwayatBarang(barangId)).length, 5);

    // Dashboard mencatat total kembali.
    final stats2 = await db.getDashboardStats();
    expect(stats2.totalStokPusat, 120);
    expect(stats2.totalKembali, 20);
  });
}
