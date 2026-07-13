import 'dart:io';

import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/barang.dart';
import '../widgets/empty_state.dart';
import '../widgets/riwayat_tile.dart';
import 'barang_edit_screen.dart';

/// Detail satu barang + riwayat transaksinya (masuk & keluar).
class BarangDetailScreen extends StatefulWidget {
  final int barangId;

  const BarangDetailScreen({super.key, required this.barangId});

  @override
  State<BarangDetailScreen> createState() => _BarangDetailScreenState();
}

class _BarangDetailScreenState extends State<BarangDetailScreen> {
  Barang? _barang;
  List<Map<String, dynamic>> _riwayat = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final barang = await DatabaseHelper.instance.getBarangById(widget.barangId);
    final riwayat =
        await DatabaseHelper.instance.getRiwayatBarang(widget.barangId);
    if (!mounted) return;
    setState(() {
      _barang = barang;
      _riwayat = riwayat;
      _loading = false;
    });
  }

  /// Buka form edit; kalau tersimpan, muat ulang agar data baru tampil.
  Future<void> _openEdit(Barang barang) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BarangEditScreen(barang: barang)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final barang = _barang;
    return Scaffold(
      appBar: AppBar(
        title: Text(barang?.nama ?? 'Detail Barang'),
        actions: [
          if (barang != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit barang',
              onPressed: () => _openEdit(barang),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : barang == null
              ? const Center(child: Text('Barang tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(barang),
                      const SizedBox(height: 20),
                      Text(
                        'Riwayat Transaksi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (_riwayat.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Belum ada transaksi')),
                        )
                      else
                        ..._riwayat.map(
                          (r) => RiwayatTile(row: r, showBarangName: false),
                        ),
                    ],
                  ),
                ),
    );
  }

  void _showFotoFull(String path) {
    showDialog(
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
  }

  Widget _header(Barang barang) {
    final scheme = Theme.of(context).colorScheme;
    final hasFoto =
        barang.fotoPath != null && File(barang.fotoPath!).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasFoto) ...[
              GestureDetector(
                onTap: () => _showFotoFull(barang.fotoPath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(barang.fotoPath!),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    barang.kodeBarang,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${barang.stokPusat}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    barang.satuan,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              barang.nama,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow('Merek', barang.merek ?? '-'),
            _infoRow('Tipe', barang.tipe ?? '-'),
            _infoRow('Stok di gudang pusat', '${barang.stokPusat} ${barang.satuan}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
