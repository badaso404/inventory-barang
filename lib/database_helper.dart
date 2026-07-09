import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/barang.dart';
import 'models/lokasi.dart';
import 'models/transaksi_keluar.dart';
import 'models/transaksi_masuk.dart';
import 'services/data_refresh.dart';

/// Singleton pengelola database SQLite lokal.
///
/// Semua operasi yang mengubah lebih dari satu tabel (barang masuk / keluar)
/// dibungkus dalam satu DB transaction supaya konsisten (atomic).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'stokbarang.db';
  static const _dbVersion = 4;

  /// Daftar Wilayah/Instansi/UKPD bawaan (Jakarta Barat).
  static const presetLokasi = <String>[
    'Badan',
    'Inspektorat Pembantu Wilayah',
    'Suku Badan Kepegawaian Daerah (SBKD)',
    'Suku Badan Kesatuan Bangsa dan Politik (Kesbangpol)',
    'Suku Badan Pendapatan Daerah (Bapenda)',
    'Suku Badan Pengelolaan Aset Daerah (BPAD)',
    'Suku Badan Pengelolaan Keuangan Daerah (BPKD)',
    'Suku Badan Perencanaan Pembangunan Daerah (Bappeda)',
    'Suku Dinas',
    'Suku Dinas Bina Marga',
    'Suku Dinas Kebudayaan',
    'Suku Dinas Cipta Karya, Tata Ruang dan Pertanahan (CKTRP)',
    'Suku Dinas Penanggulangan Kebakaran dan Penyelamatan (Gulkarmat)',
    'Suku Dinas Kependudukan dan Pencatatan Sipil (Dukcapil)',
    'Suku Dinas Kesehatan',
    'Suku Dinas Ketahanan Pangan, Kelautan dan Pertanian (KPKP)',
    'Suku Dinas Komunikasi, Informatika dan Statistik (Kominfotik)',
    'Suku Dinas Lingkungan Hidup',
    'Suku Dinas Tenaga Kerja, Transmigrasi dan Energi (Nakertransgi)',
    'Suku Dinas Pariwisata dan Ekonomi Kreatif (Parekraf)',
    'Suku Dinas Pemuda dan Olahraga',
    'Suku Dinas Pendidikan Wilayah I',
    'Suku Dinas Pendidikan Wilayah II',
    'Suku Dinas Perhubungan',
    'Suku Dinas Perpustakaan dan Kearsipan',
    'Suku Dinas Pemberdayaan, Perlindungan Anak dan Pengendalian Penduduk (PPAPP)',
    'Suku Dinas Perindustrian, Perdagangan, Koperasi, Usaha Kecil dan Menengah (PPKUKM)',
    'Suku Dinas Perumahan Rakyat dan Kawasan Permukiman (PRKP)',
    'Suku Dinas Sumber Daya Air (SDA)',
    'Suku Dinas Sosial',
    'Suku Dinas Pertamanan dan Hutan Kota',
  ];

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  /// Override path database — hanya dipakai di test (mis. sqflite_common_ffi).
  static String? debugDatabasePath;

  Future<Database> _open() async {
    final String path;
    if (debugDatabasePath != null) {
      path = debugDatabasePath!;
    } else {
      final dir = await getDatabasesPath();
      path = p.join(dir, _dbName);
    }
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Aktifkan enforcement foreign key (default SQLite mati).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// DDL tabel pengembalian barang (dari lokasi/UKPD kembali ke gudang pusat).
  static const _ddlTransaksiKembali = '''
    CREATE TABLE transaksi_kembali (
      id                 INTEGER PRIMARY KEY AUTOINCREMENT,
      barang_id          INTEGER NOT NULL REFERENCES barang(id) ON DELETE CASCADE,
      lokasi_id          INTEGER NOT NULL REFERENCES lokasi(id) ON DELETE CASCADE,
      jumlah             INTEGER NOT NULL,
      berita_acara_path  TEXT,
      keterangan         TEXT,
      user_id            INTEGER REFERENCES users(id) ON DELETE SET NULL,
      tanggal            TEXT NOT NULL
    )
  ''';

  /// Migrasi skema agar data lama tetap terpakai saat app di-update.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: tambah kolom foto barang.
      await db.execute('ALTER TABLE barang ADD COLUMN foto_path TEXT');
    }
    if (oldVersion < 3) {
      // v3: sisipkan daftar Wilayah/UKPD bawaan.
      await _seedPresetLokasi(db);
    }
    if (oldVersion < 4) {
      // v4: tabel pengembalian barang.
      await db.execute(_ddlTransaksiKembali);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        nama_lengkap  TEXT NOT NULL,
        role          TEXT NOT NULL DEFAULT 'operator'
      )
    ''');

    await db.execute('''
      CREATE TABLE barang (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_barang TEXT NOT NULL UNIQUE,
        nama        TEXT NOT NULL,
        merek       TEXT,
        tipe        TEXT,
        satuan      TEXT NOT NULL DEFAULT 'pcs',
        stok_pusat  INTEGER NOT NULL DEFAULT 0,
        foto_path   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lokasi (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_lokasi TEXT NOT NULL UNIQUE,
        nama        TEXT NOT NULL,
        alamat      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE stok_lokasi (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id INTEGER NOT NULL REFERENCES barang(id) ON DELETE CASCADE,
        lokasi_id INTEGER NOT NULL REFERENCES lokasi(id) ON DELETE CASCADE,
        jumlah    INTEGER NOT NULL DEFAULT 0,
        UNIQUE(barang_id, lokasi_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi_masuk (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id  INTEGER NOT NULL REFERENCES barang(id) ON DELETE CASCADE,
        jumlah     INTEGER NOT NULL,
        keterangan TEXT,
        user_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
        tanggal    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi_keluar (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        barang_id          INTEGER NOT NULL REFERENCES barang(id) ON DELETE CASCADE,
        lokasi_id          INTEGER NOT NULL REFERENCES lokasi(id) ON DELETE CASCADE,
        jumlah             INTEGER NOT NULL,
        berita_acara_path  TEXT,
        keterangan         TEXT,
        user_id            INTEGER REFERENCES users(id) ON DELETE SET NULL,
        tanggal            TEXT NOT NULL
      )
    ''');

    await db.execute(_ddlTransaksiKembali);

    // User default untuk testing — login: admin / admin123
    await db.insert('users', {
      'username': 'admin',
      'password_hash': hashPassword('admin123'),
      'nama_lengkap': 'Administrator',
      'role': 'admin',
    });

    // Daftar Wilayah/UKPD bawaan sebagai tujuan distribusi.
    await _seedPresetLokasi(db);
  }

  /// Sisipkan preset lokasi/UKPD yang belum ada (berdasarkan nama), dengan
  /// kode berurutan (UKPD-001, ...). Idempotent: aman dipanggil ulang saat
  /// migrasi tanpa membuat duplikat.
  Future<void> _seedPresetLokasi(DatabaseExecutor db) async {
    // Angka kode tertinggi yang sudah ada, agar penomoran lanjut.
    final maxNum = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT MAX(CAST(SUBSTR(kode_lokasi, 6) AS INTEGER)) "
          "FROM lokasi WHERE kode_lokasi LIKE 'UKPD-%'",
        )) ??
        0;
    var next = maxNum;

    for (final nama in presetLokasi) {
      final ada = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM lokasi WHERE nama = ?',
            [nama],
          )) ??
          0;
      if (ada > 0) continue; // sudah ada, lewati

      next++;
      await db.insert('lokasi', {
        'kode_lokasi': 'UKPD-${next.toString().padLeft(3, '0')}',
        'nama': nama,
        'alamat': null,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Password hashing
  // ---------------------------------------------------------------------------

  /// Hash password dengan SHA-256. Password TIDAK pernah disimpan plaintext.
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Buat user baru; password otomatis di-hash sebelum disimpan.
  Future<int> createUser({
    required String username,
    required String password,
    required String namaLengkap,
    String role = 'operator',
  }) async {
    final db = await database;
    return db.insert('users', {
      'username': username,
      'password_hash': hashPassword(password),
      'nama_lengkap': namaLengkap,
      'role': role,
    });
  }

  /// Verifikasi login. Return baris user bila cocok, null bila gagal.
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, hashPassword(password)],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Ganti password user setelah memverifikasi password lama.
  /// Return `false` bila password lama salah / user tidak ditemukan.
  Future<bool> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ? AND password_hash = ?',
      whereArgs: [userId, hashPassword(oldPassword)],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    await db.update(
      'users',
      {'password_hash': hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Barang masuk
  // ---------------------------------------------------------------------------

  /// Catat barang masuk ke gudang pusat.
  ///
  /// Jika sudah ada barang dengan kombinasi nama + merek + tipe yang sama,
  /// stok_pusat-nya ditambah. Jika belum ada, dibuat barang baru dengan
  /// kode otomatis (BRG-0001, BRG-0002, ...).
  ///
  /// Return `id` barang (baru maupun yang di-update).
  Future<int> barangMasuk({
    required String nama,
    String? merek,
    String? tipe,
    required int jumlah,
    String satuan = 'pcs',
    String? keterangan,
    int? userId,
    DateTime? tanggal,
    String? fotoPath,
  }) async {
    if (jumlah <= 0) {
      throw ArgumentError('Jumlah barang masuk harus lebih dari 0');
    }
    final tanggalIso = (tanggal ?? DateTime.now()).toIso8601String();

    final db = await database;
    final barangId = await db.transaction<int>((txn) async {
      // Cari barang identik (perlakukan NULL merek/tipe seperti string kosong).
      final existing = await txn.query(
        'barang',
        where:
            "nama = ? AND IFNULL(merek,'') = IFNULL(?,'') AND IFNULL(tipe,'') = IFNULL(?,'')",
        whereArgs: [nama, merek, tipe],
        limit: 1,
      );

      final int barangId;
      if (existing.isNotEmpty) {
        barangId = existing.first['id'] as int;
        await txn.rawUpdate(
          'UPDATE barang SET stok_pusat = stok_pusat + ? WHERE id = ?',
          [jumlah, barangId],
        );
        // Isi foto bila barang belum punya dan user melampirkan foto baru.
        if (fotoPath != null && existing.first['foto_path'] == null) {
          await txn.update(
            'barang',
            {'foto_path': fotoPath},
            where: 'id = ?',
            whereArgs: [barangId],
          );
        }
      } else {
        final kode = await _generateKodeBarang(txn);
        barangId = await txn.insert('barang', {
          'kode_barang': kode,
          'nama': nama,
          'merek': merek,
          'tipe': tipe,
          'satuan': satuan,
          'stok_pusat': jumlah,
          'foto_path': fotoPath,
        });
      }

      await txn.insert('transaksi_masuk', {
        'barang_id': barangId,
        'jumlah': jumlah,
        'keterangan': keterangan,
        'user_id': userId,
        'tanggal': tanggalIso,
      });

      return barangId;
    });

    DataRefresh.ping(); // beritahu layar lain agar reload
    return barangId;
  }

  /// Generate kode barang berikutnya (BRG-0001) berdasarkan angka terbesar
  /// yang sudah ada. Dijalankan di dalam transaction yang sama dengan insert.
  Future<String> _generateKodeBarang(DatabaseExecutor txn) async {
    final result = await txn.rawQuery(
      "SELECT MAX(CAST(SUBSTR(kode_barang, 5) AS INTEGER)) AS maxnum "
      "FROM barang WHERE kode_barang LIKE 'BRG-%'",
    );
    final maxNum = (result.first['maxnum'] as int?) ?? 0;
    final next = maxNum + 1;
    return 'BRG-${next.toString().padLeft(4, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Barang keluar (distribusi)
  // ---------------------------------------------------------------------------

  /// Distribusikan barang dari gudang pusat ke sebuah lokasi/UKPD.
  ///
  /// Memvalidasi stok_pusat mencukupi. Bila cukup: stok_pusat berkurang,
  /// stok_lokasi bertambah (upsert), lalu dicatat di transaksi_keluar.
  ///
  /// Return `false` bila stok tidak mencukupi (tidak ada perubahan data),
  /// `true` bila berhasil.
  Future<bool> barangKeluar({
    required int barangId,
    required int lokasiId,
    required int jumlah,
    String? beritaAcaraPath,
    String? keterangan,
    int? userId,
    DateTime? tanggal,
  }) async {
    if (jumlah <= 0) {
      throw ArgumentError('Jumlah barang keluar harus lebih dari 0');
    }
    final tanggalIso = (tanggal ?? DateTime.now()).toIso8601String();

    final db = await database;
    final ok = await db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'barang',
        columns: ['stok_pusat'],
        where: 'id = ?',
        whereArgs: [barangId],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final stokPusat = rows.first['stok_pusat'] as int;
      if (stokPusat < jumlah) {
        return false; // stok tidak cukup — batalkan transaksi
      }

      // Kurangi stok pusat.
      await txn.rawUpdate(
        'UPDATE barang SET stok_pusat = stok_pusat - ? WHERE id = ?',
        [jumlah, barangId],
      );

      // Upsert stok lokasi (tambah jika pasangan sudah ada).
      await txn.rawInsert(
        '''
        INSERT INTO stok_lokasi (barang_id, lokasi_id, jumlah)
        VALUES (?, ?, ?)
        ON CONFLICT(barang_id, lokasi_id)
        DO UPDATE SET jumlah = jumlah + excluded.jumlah
        ''',
        [barangId, lokasiId, jumlah],
      );

      await txn.insert('transaksi_keluar', {
        'barang_id': barangId,
        'lokasi_id': lokasiId,
        'jumlah': jumlah,
        'berita_acara_path': beritaAcaraPath,
        'keterangan': keterangan,
        'user_id': userId,
        'tanggal': tanggalIso,
      });

      return true;
    });

    if (ok) DataRefresh.ping(); // stok & riwayat berubah
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Barang kembali (retur dari lokasi ke gudang pusat)
  // ---------------------------------------------------------------------------

  /// Kembalikan barang dari sebuah lokasi/UKPD ke gudang pusat.
  ///
  /// Kebalikan dari [barangKeluar]: memvalidasi stok di lokasi mencukupi,
  /// lalu stok_lokasi berkurang, stok_pusat bertambah, dan dicatat di
  /// transaksi_kembali.
  ///
  /// Return `false` bila stok di lokasi tidak mencukupi (tanpa perubahan data),
  /// `true` bila berhasil.
  Future<bool> barangKembali({
    required int barangId,
    required int lokasiId,
    required int jumlah,
    String? beritaAcaraPath,
    String? keterangan,
    int? userId,
    DateTime? tanggal,
  }) async {
    if (jumlah <= 0) {
      throw ArgumentError('Jumlah barang kembali harus lebih dari 0');
    }
    final tanggalIso = (tanggal ?? DateTime.now()).toIso8601String();

    final db = await database;
    final ok = await db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'stok_lokasi',
        columns: ['jumlah'],
        where: 'barang_id = ? AND lokasi_id = ?',
        whereArgs: [barangId, lokasiId],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final stokLokasi = rows.first['jumlah'] as int;
      if (stokLokasi < jumlah) {
        return false; // stok di lokasi tidak cukup — batalkan
      }

      // Kurangi stok di lokasi.
      await txn.rawUpdate(
        'UPDATE stok_lokasi SET jumlah = jumlah - ? '
        'WHERE barang_id = ? AND lokasi_id = ?',
        [jumlah, barangId, lokasiId],
      );

      // Tambah kembali ke stok pusat.
      await txn.rawUpdate(
        'UPDATE barang SET stok_pusat = stok_pusat + ? WHERE id = ?',
        [jumlah, barangId],
      );

      await txn.insert('transaksi_kembali', {
        'barang_id': barangId,
        'lokasi_id': lokasiId,
        'jumlah': jumlah,
        'berita_acara_path': beritaAcaraPath,
        'keterangan': keterangan,
        'user_id': userId,
        'tanggal': tanggalIso,
      });

      return true;
    });

    if (ok) DataRefresh.ping();
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Query / laporan
  // ---------------------------------------------------------------------------

  /// Semua barang beserta stok di gudang pusat.
  Future<List<Barang>> getStokPusat() async {
    final db = await database;
    final rows = await db.query('barang', orderBy: 'nama COLLATE NOCASE ASC');
    return rows.map(Barang.fromMap).toList();
  }

  /// Barang yang tersimpan di sebuah lokasi (jumlah > 0), lengkap dengan
  /// data barangnya. Setiap map berisi field barang + `jumlah` di lokasi.
  Future<List<Map<String, dynamic>>> getBarangDiLokasi(int lokasiId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT b.id, b.kode_barang, b.nama, b.merek, b.tipe, b.satuan,
             sl.jumlah AS jumlah
      FROM stok_lokasi sl
      JOIN barang b ON b.id = sl.barang_id
      WHERE sl.lokasi_id = ? AND sl.jumlah > 0
      ORDER BY b.nama COLLATE NOCASE ASC
      ''',
      [lokasiId],
    );
  }

  /// Riwayat gabungan barang masuk, keluar & kembali, terbaru di atas.
  ///
  /// Tiap baris punya field `tipe` ('masuk' | 'keluar' | 'kembali'),
  /// `nama_barang`, `nama_lokasi` (null untuk masuk), `jumlah`, `tanggal`,
  /// `keterangan`, `berita_acara_path`.
  Future<List<Map<String, dynamic>>> getRiwayat({int? limit}) async {
    final db = await database;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery(
      '''
      SELECT 'masuk' AS tipe, tm.id AS id, tm.jumlah AS jumlah,
             tm.tanggal AS tanggal, tm.keterangan AS keterangan,
             b.nama AS nama_barang, b.kode_barang AS kode_barang,
             NULL AS nama_lokasi, NULL AS berita_acara_path
      FROM transaksi_masuk tm
      JOIN barang b ON b.id = tm.barang_id
      UNION ALL
      SELECT 'keluar' AS tipe, tk.id AS id, tk.jumlah AS jumlah,
             tk.tanggal AS tanggal, tk.keterangan AS keterangan,
             b.nama AS nama_barang, b.kode_barang AS kode_barang,
             l.nama AS nama_lokasi, tk.berita_acara_path AS berita_acara_path
      FROM transaksi_keluar tk
      JOIN barang b ON b.id = tk.barang_id
      JOIN lokasi l ON l.id = tk.lokasi_id
      UNION ALL
      SELECT 'kembali' AS tipe, tkb.id AS id, tkb.jumlah AS jumlah,
             tkb.tanggal AS tanggal, tkb.keterangan AS keterangan,
             b.nama AS nama_barang, b.kode_barang AS kode_barang,
             l.nama AS nama_lokasi, tkb.berita_acara_path AS berita_acara_path
      FROM transaksi_kembali tkb
      JOIN barang b ON b.id = tkb.barang_id
      JOIN lokasi l ON l.id = tkb.lokasi_id
      ORDER BY tanggal DESC
      $limitClause
      ''',
    );
  }

  /// Ambil satu barang berdasarkan id.
  Future<Barang?> getBarangById(int id) async {
    final db = await database;
    final rows = await db.query(
      'barang',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Barang.fromMap(rows.first);
  }

  /// Riwayat transaksi (masuk, keluar & kembali) untuk satu barang.
  Future<List<Map<String, dynamic>>> getRiwayatBarang(int barangId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT 'masuk' AS tipe, tm.jumlah AS jumlah, tm.tanggal AS tanggal,
             tm.keterangan AS keterangan, NULL AS nama_lokasi,
             NULL AS berita_acara_path
      FROM transaksi_masuk tm
      WHERE tm.barang_id = ?
      UNION ALL
      SELECT 'keluar' AS tipe, tk.jumlah AS jumlah, tk.tanggal AS tanggal,
             tk.keterangan AS keterangan, l.nama AS nama_lokasi,
             tk.berita_acara_path AS berita_acara_path
      FROM transaksi_keluar tk
      JOIN lokasi l ON l.id = tk.lokasi_id
      WHERE tk.barang_id = ?
      UNION ALL
      SELECT 'kembali' AS tipe, tkb.jumlah AS jumlah, tkb.tanggal AS tanggal,
             tkb.keterangan AS keterangan, l.nama AS nama_lokasi,
             tkb.berita_acara_path AS berita_acara_path
      FROM transaksi_kembali tkb
      JOIN lokasi l ON l.id = tkb.lokasi_id
      WHERE tkb.barang_id = ?
      ORDER BY tanggal DESC
      ''',
      [barangId, barangId, barangId],
    );
  }

  /// Ringkasan untuk dashboard. `sejak` membatasi hitungan masuk/keluar ke
  /// periode berjalan (mis. awal bulan); null = semua waktu.
  Future<DashboardStats> getDashboardStats({DateTime? sejak}) async {
    final db = await database;
    final sejakIso = sejak?.toIso8601String();

    final jenis = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM barang'),
        ) ??
        0;
    final totalStok = Sqflite.firstIntValue(
          await db.rawQuery('SELECT IFNULL(SUM(stok_pusat), 0) FROM barang'),
        ) ??
        0;

    final masukRows = await db.rawQuery(
      'SELECT IFNULL(SUM(jumlah), 0) AS total FROM transaksi_masuk'
      '${sejakIso != null ? ' WHERE tanggal >= ?' : ''}',
      sejakIso != null ? [sejakIso] : null,
    );
    final keluarRows = await db.rawQuery(
      'SELECT IFNULL(SUM(jumlah), 0) AS total FROM transaksi_keluar'
      '${sejakIso != null ? ' WHERE tanggal >= ?' : ''}',
      sejakIso != null ? [sejakIso] : null,
    );
    final kembaliRows = await db.rawQuery(
      'SELECT IFNULL(SUM(jumlah), 0) AS total FROM transaksi_kembali'
      '${sejakIso != null ? ' WHERE tanggal >= ?' : ''}',
      sejakIso != null ? [sejakIso] : null,
    );

    return DashboardStats(
      jenisBarang: jenis,
      totalStokPusat: totalStok,
      totalMasuk: (masukRows.first['total'] as num?)?.toInt() ?? 0,
      totalKeluar: (keluarRows.first['total'] as num?)?.toInt() ?? 0,
      totalKembali: (kembaliRows.first['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD lokasi (dipakai layar Wilayah/UKPD)
  // ---------------------------------------------------------------------------

  Future<int> insertLokasi(Lokasi lokasi) async {
    final db = await database;
    final id = await db.insert('lokasi', lokasi.toMap());
    DataRefresh.ping();
    return id;
  }

  Future<List<Lokasi>> getLokasi() async {
    final db = await database;
    final rows = await db.query('lokasi', orderBy: 'nama COLLATE NOCASE ASC');
    return rows.map(Lokasi.fromMap).toList();
  }

  /// Jumlah jenis barang (baris stok_lokasi > 0) di sebuah lokasi.
  Future<int> countBarangDiLokasi(int lokasiId) async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM stok_lokasi WHERE lokasi_id = ? AND jumlah > 0',
            [lokasiId],
          ),
        ) ??
        0;
  }

  /// Kode lokasi berikutnya (UKPD-001) untuk mengisi form tambah lokasi.
  Future<String> generateKodeLokasi() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT MAX(CAST(SUBSTR(kode_lokasi, 6) AS INTEGER)) AS maxnum "
      "FROM lokasi WHERE kode_lokasi LIKE 'UKPD-%'",
    );
    final maxNum = (result.first['maxnum'] as int?) ?? 0;
    return 'UKPD-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Akses transaksi (opsional, typed)
  // ---------------------------------------------------------------------------

  Future<List<TransaksiMasuk>> getTransaksiMasuk({int? barangId}) async {
    final db = await database;
    final rows = await db.query(
      'transaksi_masuk',
      where: barangId != null ? 'barang_id = ?' : null,
      whereArgs: barangId != null ? [barangId] : null,
      orderBy: 'tanggal DESC',
    );
    return rows.map(TransaksiMasuk.fromMap).toList();
  }

  Future<List<TransaksiKeluar>> getTransaksiKeluar({int? lokasiId}) async {
    final db = await database;
    final rows = await db.query(
      'transaksi_keluar',
      where: lokasiId != null ? 'lokasi_id = ?' : null,
      whereArgs: lokasiId != null ? [lokasiId] : null,
      orderBy: 'tanggal DESC',
    );
    return rows.map(TransaksiKeluar.fromMap).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}

/// Angka ringkasan untuk dashboard.
class DashboardStats {
  final int jenisBarang;
  final int totalStokPusat;
  final int totalMasuk;
  final int totalKeluar;
  final int totalKembali;

  const DashboardStats({
    required this.jenisBarang,
    required this.totalStokPusat,
    required this.totalMasuk,
    required this.totalKeluar,
    required this.totalKembali,
  });
}
