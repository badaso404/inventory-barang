import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database_helper.dart';
import '../models/barang.dart';
import '../services/file_storage.dart';

/// Form perbaikan data barang (mis. salah ketik nama saat barang masuk).
///
/// Hanya data deskriptif yang bisa diubah — stok tidak, karena stok harus
/// selalu berasal dari transaksi masuk/keluar/kembali agar bisa ditelusuri.
class BarangEditScreen extends StatefulWidget {
  final Barang barang;

  const BarangEditScreen({super.key, required this.barang});

  @override
  State<BarangEditScreen> createState() => _BarangEditScreenState();
}

class _BarangEditScreenState extends State<BarangEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  late final TextEditingController _merekCtrl;
  late final TextEditingController _tipeCtrl;

  late String _satuan;
  static const _satuanOptions = ['pcs', 'unit', 'box', 'pack', 'rim', 'lusin'];

  String? _fotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.barang;
    _namaCtrl = TextEditingController(text: b.nama);
    _merekCtrl = TextEditingController(text: b.merek ?? '');
    _tipeCtrl = TextEditingController(text: b.tipe ?? '');
    _fotoPath = b.fotoPath;
    // Satuan lama bisa saja di luar daftar (mis. data lama) — tambahkan agar
    // dropdown tidak error karena value-nya tidak ada di items.
    _satuan = _satuanOptions.contains(b.satuan) ? b.satuan : _satuanOptions.first;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _merekCtrl.dispose();
    _tipeCtrl.dispose();
    super.dispose();
  }

  String? _trimOrNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _pickFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      final saved = await FileStorage.saveFotoBarang(picked.path);
      if (!mounted) return;
      setState(() => _fotoPath = saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final ok = await DatabaseHelper.instance.updateBarang(
        id: widget.barang.id!,
        nama: _namaCtrl.text.trim(),
        merek: _trimOrNull(_merekCtrl.text),
        tipe: _trimOrNull(_tipeCtrl.text),
        satuan: _satuan,
        fotoPath: _fotoPath,
      );

      if (!mounted) return;
      if (!ok) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: const Text(
              'Sudah ada barang lain dengan nama, merek, dan tipe yang sama',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Data "${_namaCtrl.text.trim()}" berhasil diperbarui'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Gagal menyimpan: $e'),
        ),
      );
    }
  }

  Widget _fotoPicker() {
    final scheme = Theme.of(context).colorScheme;
    final hasFoto = _fotoPath != null && File(_fotoPath!).existsSync();
    return Column(
      children: [
        GestureDetector(
          onTap: _pickFoto,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
              image: hasFoto
                  ? DecorationImage(
                      image: FileImage(File(_fotoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasFoto
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: scheme.primary, size: 30),
                      const SizedBox(height: 6),
                      Text('Tambah Foto',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
          ),
        ),
        if (hasFoto)
          TextButton.icon(
            onPressed: () => setState(() => _fotoPath = null),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Hapus foto'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final barang = widget.barang;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Barang')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: _fotoPicker()),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: barang.kodeBarang,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Kode Barang',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama barang wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _merekCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Merek (opsional)',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipe (opsional)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _satuan,
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: _satuanOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _satuan = v ?? _satuan),
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kode barang dan jumlah stok tidak dapat diubah di '
                          'sini. Stok hanya berubah lewat transaksi masuk, '
                          'keluar, dan kembali agar riwayatnya tetap utuh.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
