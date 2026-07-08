/// Barang di gudang pusat. `stokPusat` adalah jumlah yang belum
/// didistribusikan ke lokasi/UKPD manapun.
class Barang {
  final int? id;
  final String kodeBarang; // format BRG-0001
  final String nama;
  final String? merek;
  final String? tipe;
  final String satuan;
  final int stokPusat;
  final String? fotoPath; // path foto barang di storage app (opsional)

  const Barang({
    this.id,
    required this.kodeBarang,
    required this.nama,
    this.merek,
    this.tipe,
    required this.satuan,
    this.stokPusat = 0,
    this.fotoPath,
  });

  factory Barang.fromMap(Map<String, dynamic> map) {
    return Barang(
      id: map['id'] as int?,
      kodeBarang: map['kode_barang'] as String,
      nama: map['nama'] as String,
      merek: map['merek'] as String?,
      tipe: map['tipe'] as String?,
      satuan: map['satuan'] as String,
      stokPusat: (map['stok_pusat'] as int?) ?? 0,
      fotoPath: map['foto_path'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kode_barang': kodeBarang,
      'nama': nama,
      'merek': merek,
      'tipe': tipe,
      'satuan': satuan,
      'stok_pusat': stokPusat,
      'foto_path': fotoPath,
    };
  }

  Barang copyWith({
    int? id,
    String? kodeBarang,
    String? nama,
    String? merek,
    String? tipe,
    String? satuan,
    int? stokPusat,
    String? fotoPath,
  }) {
    return Barang(
      id: id ?? this.id,
      kodeBarang: kodeBarang ?? this.kodeBarang,
      nama: nama ?? this.nama,
      merek: merek ?? this.merek,
      tipe: tipe ?? this.tipe,
      satuan: satuan ?? this.satuan,
      stokPusat: stokPusat ?? this.stokPusat,
      fotoPath: fotoPath ?? this.fotoPath,
    );
  }
}
