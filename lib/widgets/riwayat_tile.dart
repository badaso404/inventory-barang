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
    final tipe = row['tipe'] as String;
    final isMasuk = tipe == 'masuk';
    final isKeluar = tipe == 'keluar';
    final isKembali = tipe == 'kembali';
    final jumlah = (row['jumlah'] as num?)?.toInt() ?? 0;
    final namaBarang = row['nama_barang'] as String?;
    final namaLokasi = row['nama_lokasi'] as String?;
    final keterangan = row['keterangan'] as String?;
    final beritaAcara = row['berita_acara_path'] as String?;
    final hasBeritaAcara = beritaAcara != null && beritaAcara.isNotEmpty;

    // Stok pusat bertambah untuk masuk & kembali, berkurang untuk keluar.
    final naik = isMasuk || isKembali;

    final Color color;
    final IconData icon;
    final String tipeLabel;
    if (isMasuk) {
      color = AppTheme.masuk;
      icon = Icons.arrow_downward;
      tipeLabel = 'Barang Masuk';
    } else if (isKeluar) {
      color = AppTheme.keluar;
      icon = Icons.arrow_upward;
      tipeLabel = 'Barang Keluar';
    } else {
      color = AppTheme.kembali;
      icon = Icons.keyboard_return;
      tipeLabel = 'Barang Kembali';
    }

    final title = (showBarangName && namaBarang != null)
        ? namaBarang
        : tipeLabel;

    final String lokasiLine;
    if (isMasuk) {
      lokasiLine = 'Masuk ke gudang pusat';
    } else if (isKeluar) {
      lokasiLine = '→ ${namaLokasi ?? '-'}';
    } else {
      lokasiLine = '← kembali dari ${namaLokasi ?? '-'}';
    }

    final subtitleParts = <String>[
      lokasiLine,
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
        child: Icon(icon, color: color),
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
        '${naik ? '+' : '-'}$jumlah',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
