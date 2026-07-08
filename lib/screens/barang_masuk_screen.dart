import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../database_helper.dart';
import '../services/file_storage.dart';
import '../services/session_manager.dart';
import '../utils/format.dart';

/// Form barang masuk ke gudang pusat.
///
/// User cukup input nama, merek, tipe (opsional), satuan, dan jumlah.
/// Kode/ID barang di-generate otomatis oleh DatabaseHelper.barangMasuk().
class BarangMasukScreen extends StatefulWidget {
  const BarangMasukScreen({super.key});

  @override
  State<BarangMasukScreen> createState() => _BarangMasukScreenState();
}

class _BarangMasukScreenState extends State<BarangMasukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _merekCtrl = TextEditingController();
  final _tipeCtrl = TextEditingController();
  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();

  String _satuan = 'pcs';
  static const _satuanOptions = ['pcs', 'unit', 'box', 'pack', 'rim', 'lusin'];

  DateTime _tanggal = DateTime.now();
  String? _fotoPath; // foto barang (opsional), sudah disalin ke storage app
  bool _saving = false;

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

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _merekCtrl.dispose();
    _tipeCtrl.dispose();
    _jumlahCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  String? _trimOrNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = await SessionManager.instance.currentUser();
      await DatabaseHelper.instance.barangMasuk(
        nama: _namaCtrl.text.trim(),
        merek: _trimOrNull(_merekCtrl.text),
        tipe: _trimOrNull(_tipeCtrl.text),
        jumlah: int.parse(_jumlahCtrl.text.trim()),
        satuan: _satuan,
        keterangan: _trimOrNull(_keteranganCtrl.text),
        userId: user?.id,
        tanggal: Format.withCurrentTime(_tanggal),
        fotoPath: _fotoPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            '${_jumlahCtrl.text.trim()} $_satuan "${_namaCtrl.text.trim()}" '
            'berhasil ditambahkan ke stok pusat',
          ),
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
              image: _fotoPath != null
                  ? DecorationImage(
                      image: FileImage(File(_fotoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _fotoPath != null
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
        if (_fotoPath != null)
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
    return Scaffold(
      appBar: AppBar(title: const Text('Barang Masuk')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: _fotoPicker()),
              const SizedBox(height: 20),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _jumlahCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah *',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Angka tidak valid';
                        if (n <= 0) return 'Harus > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _satuan,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: _satuanOptions
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _satuan = v ?? _satuan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickTanggal,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Masuk',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(Format.tanggal(_tanggal.toIso8601String())),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keteranganCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
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
                          'Kode barang dibuat otomatis (BRG-0001). Jika nama, '
                          'merek, dan tipe sama dengan barang yang sudah ada, '
                          'stoknya akan ditambahkan.',
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
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Barang Masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
