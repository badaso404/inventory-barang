/// Lokasi / instansi / UKPD tujuan distribusi barang.
class Lokasi {
  final int? id;
  final String kodeLokasi;
  final String nama;
  final String? alamat;

  const Lokasi({
    this.id,
    required this.kodeLokasi,
    required this.nama,
    this.alamat,
  });

  factory Lokasi.fromMap(Map<String, dynamic> map) {
    return Lokasi(
      id: map['id'] as int?,
      kodeLokasi: map['kode_lokasi'] as String,
      nama: map['nama'] as String,
      alamat: map['alamat'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kode_lokasi': kodeLokasi,
      'nama': nama,
      'alamat': alamat,
    };
  }

  Lokasi copyWith({
    int? id,
    String? kodeLokasi,
    String? nama,
    String? alamat,
  }) {
    return Lokasi(
      id: id ?? this.id,
      kodeLokasi: kodeLokasi ?? this.kodeLokasi,
      nama: nama ?? this.nama,
      alamat: alamat ?? this.alamat,
    );
  }
}
