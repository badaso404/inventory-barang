import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../database_helper.dart';
import '../models/barang.dart';
import '../models/lokasi.dart';
import '../services/file_storage.dart';
import '../services/session_manager.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

/// Form barang keluar / distribusi dari gudang pusat ke sebuah lokasi/UKPD.
///
/// User memilih barang (hanya yang stok pusatnya > 0), jumlah, lokasi tujuan,
/// dan meng-upload berita acara. Jumlah divalidasi tidak melebihi stok pusat;
/// transaksi ditolak jika stok kurang.
class BarangKeluarScreen extends StatefulWidget {
  const BarangKeluarScreen({super.key});

  @override
  State<BarangKeluarScreen> createState() => _BarangKeluarScreenState();
}

class _BarangKeluarScreenState extends State<BarangKeluarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();

  List<Barang> _barangList = [];
  List<Lokasi> _lokasiList = [];
  Barang? _selectedBarang;
  Lokasi? _selectedLokasi;

  String? _beritaAcaraPath; // path file yang sudah disalin ke storage app
  DateTime _tanggal = DateTime.now();

  bool _loading = true;
  bool _saving = false;

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
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final barang = await DatabaseHelper.instance.getStokPusat();
    final lokasi = await DatabaseHelper.instance.getLokasi();
    if (!mounted) return;
    setState(() {
      // Hanya barang yang masih ada stoknya di pusat yang bisa didistribusikan.
      _barangList = barang.where((b) => b.stokPusat > 0).toList();
      _lokasiList = lokasi;
      _loading = false;
    });
  }

  // --- Pemilihan berita acara -----------------------------------------------

  Future<void> _pickBeritaAcara() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('File (PDF/Dokumen)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    try {
      String? sourcePath;
      if (choice == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        );
        sourcePath = result?.files.single.path;
      } else {
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 80,
        );
        sourcePath = picked?.path;
      }

      if (sourcePath == null) return; // dibatalkan user

      final savedPath = await FileStorage.saveBeritaAcara(sourcePath);
      if (!mounted) return;
      setState(() => _beritaAcaraPath = savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
    }
  }

  // --- Simpan transaksi ------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBarang == null) {
      _snack('Pilih barang terlebih dahulu');
      return;
    }
    if (_selectedLokasi == null) {
      _snack('Pilih lokasi tujuan terlebih dahulu');
      return;
    }

    final jumlah = int.parse(_jumlahCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final user = await SessionManager.instance.currentUser();
      final ok = await DatabaseHelper.instance.barangKeluar(
        barangId: _selectedBarang!.id!,
        lokasiId: _selectedLokasi!.id!,
        jumlah: jumlah,
        beritaAcaraPath: _beritaAcaraPath,
        keterangan: _keteranganCtrl.text.trim().isEmpty
            ? null
            : _keteranganCtrl.text.trim(),
        userId: user?.id,
        tanggal: Format.withCurrentTime(_tanggal),
      );

      if (!mounted) return;

      if (!ok) {
        setState(() => _saving = false);
        _snack(
          'Stok pusat tidak mencukupi untuk "${_selectedBarang!.nama}"',
          error: true,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            '$jumlah ${_selectedBarang!.satuan} "${_selectedBarang!.nama}" '
            'didistribusikan ke ${_selectedLokasi!.nama}',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Gagal menyimpan: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            error ? Theme.of(context).colorScheme.error : null,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barang Keluar')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView();
    }
    if (_barangList.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        message:
            'Belum ada barang dengan stok di gudang pusat.\nTambahkan lewat '
            'Barang Masuk terlebih dahulu.',
      );
    }
    if (_lokasiList.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        message: 'Belum ada lokasi/UKPD tujuan.',
      );
    }

    final stok = _selectedBarang?.stokPusat;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<Barang>(
            initialValue: _selectedBarang,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Pilih Barang *',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: _barangList
                .map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                      '${b.kodeBarang} • ${b.nama} (stok ${b.stokPusat})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (b) => setState(() => _selectedBarang = b),
            validator: (v) => v == null ? 'Barang wajib dipilih' : null,
          ),
          if (stok != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stok pusat tersedia: $stok ${_selectedBarang!.satuan}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _jumlahCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah Distribusi *',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Angka tidak valid';
              if (n <= 0) return 'Harus > 0';
              if (stok != null && n > stok) {
                return 'Melebihi stok pusat ($stok)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Lokasi>(
            initialValue: _selectedLokasi,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Lokasi Tujuan *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: _lokasiList
                .map(
                  (l) => DropdownMenuItem(
                    value: l,
                    child: Text(
                      '${l.kodeLokasi} • ${l.nama}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (l) => setState(() => _selectedLokasi = l),
            validator: (v) => v == null ? 'Lokasi wajib dipilih' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickTanggal,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal Distribusi',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(Format.tanggal(_tanggal.toIso8601String())),
            ),
          ),
          const SizedBox(height: 16),
          _BeritaAcaraPicker(
            path: _beritaAcaraPath,
            onPick: _pickBeritaAcara,
            onClear: () => setState(() => _beritaAcaraPath = null),
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
          const SizedBox(height: 24),
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
                : const Icon(Icons.local_shipping_outlined),
            label: Text(_saving ? 'Menyimpan...' : 'Distribusikan'),
          ),
        ],
      ),
    );
  }
}

/// Kartu untuk memilih / menampilkan file berita acara.
class _BeritaAcaraPicker extends StatelessWidget {
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _BeritaAcaraPicker({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  bool get _isImage {
    if (path == null) return false;
    final ext = p.extension(path!).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload Berita Acara'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: _isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path!),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(Icons.description_outlined, color: scheme.primary),
        title: const Text('Berita acara terlampir'),
        subtitle: Text(
          p.basename(path!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Ganti',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onPick,
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
