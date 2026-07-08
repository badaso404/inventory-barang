import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Menyalin file yang dipilih user (berita acara / foto barang) ke storage
/// internal app, lalu mengembalikan path permanennya untuk disimpan ke DB.
///
/// File dari image_picker/file_picker biasanya berada di cache sementara,
/// jadi harus disalin agar tidak hilang.
class FileStorage {
  FileStorage._();

  /// Salin file ke subfolder tertentu dengan prefix nama file.
  static Future<String> _save(
    String sourcePath, {
    required String folder,
    required String prefix,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(dir.path, folder));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    final ext = p.extension(sourcePath);
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(target.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<String> saveBeritaAcara(String sourcePath) =>
      _save(sourcePath, folder: 'berita_acara', prefix: 'ba');

  static Future<String> saveFotoBarang(String sourcePath) =>
      _save(sourcePath, folder: 'foto_barang', prefix: 'brg');
}
