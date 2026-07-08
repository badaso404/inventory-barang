/// Utilitas format tanggal sederhana (tanpa dependency intl).
class Format {
  Format._();

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// ISO-8601 → "08 Jul 2026, 14:30". Kembalikan string asli bila gagal parse.
  static String tanggalJam(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_pad(d.day)} ${_bulan[d.month - 1]} ${d.year}, '
        '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  /// ISO-8601 → "08 Jul 2026".
  static String tanggal(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_pad(d.day)} ${_bulan[d.month - 1]} ${d.year}';
  }

  /// DateTime → "08 Jul 2026".
  static String tanggalOf(DateTime d) =>
      '${_pad(d.day)} ${_bulan[d.month - 1]} ${d.year}';

  /// Gabungkan tanggal pilihan user dengan jam saat ini, supaya urutan
  /// transaksi dalam hari yang sama tetap masuk akal.
  static DateTime withCurrentTime(DateTime date) {
    final now = DateTime.now();
    return DateTime(
        date.year, date.month, date.day, now.hour, now.minute, now.second);
  }
}
