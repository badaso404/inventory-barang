/// Catatan barang keluar (distribusi) dari gudang pusat ke sebuah lokasi/UKPD.
/// Mengurangi stok_pusat dan menambah stok_lokasi.
class TransaksiKeluar {
  final int? id;
  final int barangId;
  final int lokasiId;
  final int jumlah;
  final String? beritaAcaraPath; // path file berita acara di device
  final String? keterangan;
  final int? userId;
  final String tanggal; // ISO-8601 string

  const TransaksiKeluar({
    this.id,
    required this.barangId,
    required this.lokasiId,
    required this.jumlah,
    this.beritaAcaraPath,
    this.keterangan,
    this.userId,
    required this.tanggal,
  });

  factory TransaksiKeluar.fromMap(Map<String, dynamic> map) {
    return TransaksiKeluar(
      id: map['id'] as int?,
      barangId: map['barang_id'] as int,
      lokasiId: map['lokasi_id'] as int,
      jumlah: map['jumlah'] as int,
      beritaAcaraPath: map['berita_acara_path'] as String?,
      keterangan: map['keterangan'] as String?,
      userId: map['user_id'] as int?,
      tanggal: map['tanggal'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barang_id': barangId,
      'lokasi_id': lokasiId,
      'jumlah': jumlah,
      'berita_acara_path': beritaAcaraPath,
      'keterangan': keterangan,
      'user_id': userId,
      'tanggal': tanggal,
    };
  }
}
