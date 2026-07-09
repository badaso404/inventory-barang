import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../database_helper.dart';
import '../models/lokasi.dart';
import '../services/file_storage.dart';
import '../services/session_manager.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

/// Form barang kembali (retur): barang dari sebuah lokasi/UKPD dikembalikan
/// ke gudang pusat. Kebalikan dari Barang Keluar.
class BarangKembaliScreen extends StatefulWidget {
  const BarangKembaliScreen({super.key});

  @override
  State<BarangKembaliScreen> createState() => _BarangKembaliScreenState();
}

class _BarangKembaliScreenState extends State<BarangKembaliScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();

  List<Lokasi> _lokasiList = [];
  List<Map<String, dynamic>> _barangDiLokasi = [];
  Lokasi? _selectedLokasi;
  int? _selectedBarangId; // pakai id (int) sebagai value dropdown — stabil & unik

  /// Data barang terpilih (dicari dari list berdasarkan id).
  Map<String, dynamic>? get _selectedBarang {
    for (final b in _barangDiLokasi) {
      if (b['id'] == _selectedBarangId) return b;
    }
    return null;
  }

  String? _beritaAcaraPath;
  DateTime _tanggal = DateTime.now();

  bool _loading = true;
  bool _loadingBarang = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLokasi();
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLokasi() async {
    final lokasi = await DatabaseHelper.instance.getLokasi();
    if (!mounted) return;
    setState(() {
      _lokasiList = lokasi;
      _loading = false;
    });
  }

  Future<void> _onLokasiChanged(Lokasi? lokasi) async {
    setState(() {
      _selectedLokasi = lokasi;
      _selectedBarangId = null;
      _barangDiLokasi = [];
      _loadingBarang = lokasi != null;
    });
    if (lokasi == null) return;

    final barang = await DatabaseHelper.instance.getBarangDiLokasi(lokasi.id!);
    if (!mounted) return;
    setState(() {
      _barangDiLokasi = barang;
      _loadingBarang = false;
    });
  }

  int? get _stokDiLokasi => _selectedBarang?['jumlah'] as int?;

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

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
          source:
              choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
        );
        sourcePath = picked?.path;
      }
      if (sourcePath == null) return;

      final saved = await FileStorage.saveBeritaAcara(sourcePath);
      if (!mounted) return;
      setState(() => _beritaAcaraPath = saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memilih file: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLokasi == null) {
      _snack('Pilih lokasi asal terlebih dahulu');
      return;
    }
    if (_selectedBarang == null) {
      _snack('Pilih barang terlebih dahulu');
      return;
    }

    final jumlah = int.parse(_jumlahCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final user = await SessionManager.instance.currentUser();
      final ok = await DatabaseHelper.instance.barangKembali(
        barangId: _selectedBarang!['id'] as int,
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
        _snack('Stok di lokasi tidak mencukupi', error: true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            '$jumlah ${_selectedBarang!['satuan']} '
            '"${_selectedBarang!['nama']}" dikembalikan ke gudang pusat',
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
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barang Kembali')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_lokasiList.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        message: 'Belum ada lokasi/UKPD.',
      );
    }

    final stok = _stokDiLokasi;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<Lokasi>(
            initialValue: _selectedLokasi,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Lokasi Asal *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: _lokasiList
                .map(
                  (l) => DropdownMenuItem(
                    value: l,
                    child: Text('${l.kodeLokasi} • ${l.nama}',
                        overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _onLokasiChanged,
            validator: (v) => v == null ? 'Lokasi wajib dipilih' : null,
          ),
          const SizedBox(height: 16),
          _buildBarangField(),
          if (stok != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stok di lokasi: $stok ${_selectedBarang!['satuan']}',
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
              labelText: 'Jumlah Dikembalikan *',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Angka tidak valid';
              if (n <= 0) return 'Harus > 0';
              if (stok != null && n > stok) {
                return 'Melebihi stok di lokasi ($stok)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickTanggal,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal Kembali',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(Format.tanggal(_tanggal.toIso8601String())),
            ),
          ),
          const SizedBox(height: 16),
          _buildBeritaAcara(),
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
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.keyboard_return),
            label: Text(_saving ? 'Menyimpan...' : 'Kembalikan ke Pusat'),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangField() {
    if (_loadingBarang) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (_selectedLokasi != null && _barangDiLokasi.isEmpty) {
      return Text(
        'Tidak ada barang di lokasi ini.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _selectedBarangId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Pilih Barang *',
        prefixIcon: Icon(Icons.inventory_2_outlined),
      ),
      items: _barangDiLokasi
          .map(
            (b) => DropdownMenuItem(
              value: b['id'] as int,
              child: Text(
                '${b['kode_barang']} • ${b['nama']} (ada ${b['jumlah']})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _selectedLokasi == null
          ? null
          : (id) => setState(() => _selectedBarangId = id),
      validator: (v) => v == null ? 'Barang wajib dipilih' : null,
    );
  }

  Widget _buildBeritaAcara() {
    final scheme = Theme.of(context).colorScheme;
    if (_beritaAcaraPath == null) {
      return OutlinedButton.icon(
        onPressed: _pickBeritaAcara,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload Berita Acara (opsional)'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      );
    }
    final ext = p.extension(_beritaAcaraPath!).toLowerCase();
    final isImage = ext == '.jpg' || ext == '.jpeg' || ext == '.png';
    return Card(
      child: ListTile(
        leading: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_beritaAcaraPath!),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            : Icon(Icons.description_outlined, color: scheme.primary),
        title: const Text('Berita acara terlampir'),
        subtitle: Text(p.basename(_beritaAcaraPath!),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _beritaAcaraPath = null),
        ),
      ),
    );
  }
}
