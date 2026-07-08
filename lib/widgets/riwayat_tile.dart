import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/format.dart';
import 'berita_acara_view.dart';

/// Baris riwayat transaksi yang dipakai ulang di tab Riwayat, Dashboard,
/// dan detail barang. `row` adalah satu map hasil getRiwayat / getRiwayatBarang.
///
/// Field yang dipakai: tipe ('masuk'|'keluar'), jumlah, tanggal, keterangan,
/// nama_barang (opsional), nama_lokasi (opsional untuk keluar).
class RiwayatTile extends StatelessWidget {
  final Map<String, dynamic> row;

  /// Bila true, judul memakai nama barang (untuk daftar campuran).
  /// Bila false, judul memakai label tipe (untuk detail satu barang).
  final bool showBarangName;

  const RiwayatTile({
    super.key,
    required this.row,
    this.showBarangName = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMasuk = row['tipe'] == 'masuk';
    final jumlah = row['jumlah'] as int;
    final namaBarang = row['nama_barang'] as String?;
    final namaLokasi = row['nama_lokasi'] as String?;
    final keterangan = row['keterangan'] as String?;
    final beritaAcara = row['berita_acara_path'] as String?;
    final hasBeritaAcara = beritaAcara != null && beritaAcara.isNotEmpty;

    final color = isMasuk ? AppTheme.masuk : AppTheme.keluar;

    final String title;
    if (showBarangName && namaBarang != null) {
      title = namaBarang;
    } else {
      title = isMasuk ? 'Barang Masuk' : 'Barang Keluar';
    }

    final subtitleParts = <String>[
      if (isMasuk) 'Masuk ke gudang pusat' else '→ ${namaLokasi ?? '-'}',
      Format.tanggalJam(row['tanggal'] as String),
      if (keterangan != null && keterangan.isNotEmpty) keterangan,
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: hasBeritaAcara
          ? () => openBeritaAcara(context, beritaAcara)
          : null,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(
          isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitleParts.join('\n')),
          if (hasBeritaAcara)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 14, color: color),
                  const SizedBox(width: 3),
                  Text(
                    'Lihat berita acara',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      isThreeLine: subtitleParts.length > 2,
      trailing: Text(
        '${isMasuk ? '+' : '-'}$jumlah',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
