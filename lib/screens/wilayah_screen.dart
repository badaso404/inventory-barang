import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/lokasi.dart';
import '../services/data_refresh.dart';
import '../widgets/empty_state.dart';
import 'lokasi_detail_screen.dart';

/// Daftar Wilayah/Instansi/UKPD. Tap → barang di lokasi tsb. Ada form tambah.
class WilayahScreen extends StatefulWidget {
  const WilayahScreen({super.key});

  @override
  State<WilayahScreen> createState() => _WilayahScreenState();
}

class _WilayahScreenState extends State<WilayahScreen> {
  List<Lokasi> _lokasi = [];
  Map<int, int> _counts = {}; // lokasiId → jumlah jenis barang
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    DataRefresh.notifier.addListener(_load);
  }

  @override
  void dispose() {
    DataRefresh.notifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final lokasi = await DatabaseHelper.instance.getLokasi();
    final counts = <int, int>{};
    for (final l in lokasi) {
      counts[l.id!] =
          await DatabaseHelper.instance.countBarangDiLokasi(l.id!);
    }
    if (!mounted) return;
    setState(() {
      _lokasi = lokasi;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _tambahLokasi() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TambahLokasiSheet(),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wilayah / UKPD')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahLokasi,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: _lokasi.isEmpty
                  ? const EmptyState(
                      icon: Icons.location_off_outlined,
                      message: 'Belum ada lokasi/UKPD.\n'
                          'Tekan tombol Tambah untuk menambahkan.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lokasi.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final l = _lokasi[i];
                        final scheme = Theme.of(context).colorScheme;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(Icons.location_city,
                                  color: scheme.onPrimaryContainer),
                            ),
                            title: Text(
                              l.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${l.kodeLokasi} • ${_counts[l.id] ?? 0} jenis barang',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LokasiDetailScreen(lokasi: l),
                                ),
                              );
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Form (bottom sheet) tambah lokasi baru. Kode di-suggest otomatis.
class _TambahLokasiSheet extends StatefulWidget {
  const _TambahLokasiSheet();

  @override
  State<_TambahLokasiSheet> createState() => _TambahLokasiSheetState();
}

class _TambahLokasiSheetState extends State<_TambahLokasiSheet> {
  final _formKey = GlobalKey<FormState>();
  final _kodeCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _suggestKode();
  }

  Future<void> _suggestKode() async {
    final kode = await DatabaseHelper.instance.generateKodeLokasi();
    if (!mounted) return;
    if (_kodeCtrl.text.isEmpty) _kodeCtrl.text = kode;
  }

  @override
  void dispose() {
    _kodeCtrl.dispose();
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.insertLokasi(
        Lokasi(
          kodeLokasi: _kodeCtrl.text.trim(),
          nama: _namaCtrl.text.trim(),
          alamat: _alamatCtrl.text.trim().isEmpty
              ? null
              : _alamatCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().contains('UNIQUE')
          ? 'Kode lokasi sudah dipakai'
          : 'Gagal menyimpan: $e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tambah Lokasi / UKPD',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode Lokasi *',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Kode wajib diisi'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _namaCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Lokasi *',
                prefixIcon: Icon(Icons.location_city),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama wajib diisi'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _alamatCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat (opsional)',
                prefixIcon: Icon(Icons.place_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
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
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Lokasi'),
            ),
          ],
        ),
      ),
    );
  }
}
