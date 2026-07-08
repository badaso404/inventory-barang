import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

/// Membuka berita acara agar bisa dibaca admin.
///
/// - Bila file gambar (jpg/jpeg/png) → tampil fullscreen (bisa di-zoom).
/// - Bila PDF/dokumen → dibuka dengan aplikasi bawaan perangkat.
/// - Bila file tidak ditemukan → tampilkan pesan.
Future<void> openBeritaAcara(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!File(path).existsSync()) {
    messenger.showSnackBar(
      const SnackBar(content: Text('File berita acara tidak ditemukan')),
    );
    return;
  }

  final ext = p.extension(path).toLowerCase();
  final isImage = ext == '.jpg' || ext == '.jpeg' || ext == '.png';

  if (isImage) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  } else {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(content: Text('Tidak bisa membuka file: ${result.message}')),
      );
    }
  }
}
