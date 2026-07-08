/// Catatan barang masuk ke gudang pusat (menambah stok_pusat).
class TransaksiMasuk {
  final int? id;
  final int barangId;
  final int jumlah;
  final String? keterangan;
  final int? userId;
  final String tanggal; // ISO-8601 string

  const TransaksiMasuk({
    this.id,
    required this.barangId,
    required this.jumlah,
    this.keterangan,
    this.userId,
    required this.tanggal,
  });

  factory TransaksiMasuk.fromMap(Map<String, dynamic> map) {
    return TransaksiMasuk(
      id: map['id'] as int?,
      barangId: map['barang_id'] as int,
      jumlah: map['jumlah'] as int,
      keterangan: map['keterangan'] as String?,
      userId: map['user_id'] as int?,
      tanggal: map['tanggal'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barang_id': barangId,
      'jumlah': jumlah,
      'keterangan': keterangan,
      'user_id': userId,
      'tanggal': tanggal,
    };
  }
}
