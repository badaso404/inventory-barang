import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../database_helper.dart';
import '../models/barang.dart';
import '../services/data_refresh.dart';
import '../widgets/empty_state.dart';
import 'barang_detail_screen.dart';
import 'barang_kembali_screen.dart';
import 'barang_keluar_screen.dart';
import 'barang_masuk_screen.dart';

enum _StokFilter { semua, adaStok, habis }

/// Tab Barang: daftar stok keseluruhan (gudang pusat) dengan search & filter,
/// plus entry point ke transaksi Barang Masuk & Barang Keluar.
class BarangScreen extends StatefulWidget {
  const BarangScreen({super.key});

  @override
  State<BarangScreen> createState() => _BarangScreenState();
}

class _BarangScreenState extends State<BarangScreen> {
  final _searchCtrl = TextEditingController();

  List<Barang> _all = [];
  bool _loading = true;
  String _query = '';
  _StokFilter _filter = _StokFilter.semua;

  @override
  void initState() {
    super.initState();
    _load();
    DataRefresh.notifier.addListener(_load);
  }

  @override
  void dispose() {
    DataRefresh.notifier.removeListener(_load);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getStokPusat();
    if (!mounted) return;
    setState(() {
      _all = data;
      _loading = false;
    });
  }

  Future<void> _openForm(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (changed == true) _load();
  }

  List<Barang> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((b) {
      final matchQuery = q.isEmpty ||
          b.nama.toLowerCase().contains(q) ||
          b.kodeBarang.toLowerCase().contains(q) ||
          (b.merek?.toLowerCase().contains(q) ?? false);
      final matchFilter = switch (_filter) {
        _StokFilter.semua => true,
        _StokFilter.adaStok => b.stokPusat > 0,
        _StokFilter.habis => b.stokPusat <= 0,
      };
      return matchQuery && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _quickActions(),
        _searchAndFilter(),
        Expanded(
          child: _loading
              ? const LoadingView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(),
                ),
        ),
      ],
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.add_box_outlined,
              color: AppTheme.masuk,
              label: 'Masuk',
              onTap: () => _openForm(const BarangMasukScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.local_shipping_outlined,
              color: AppTheme.keluar,
              label: 'Keluar',
              onTap: () => _openForm(const BarangKeluarScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.keyboard_return,
              color: AppTheme.kembali,
              label: 'Kembali',
              onTap: () => _openForm(const BarangKembaliScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari kode / nama / merek...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _filterChip('Semua', _StokFilter.semua),
              const SizedBox(width: 8),
              _filterChip('Ada Stok', _StokFilter.adaStok),
              const SizedBox(width: 8),
              _filterChip('Habis', _StokFilter.habis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _StokFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        message: _all.isEmpty
            ? 'Belum ada barang.\nTambah lewat tombol Barang Masuk di atas.'
            : 'Tidak ada barang yang cocok dengan pencarian/filter.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _BarangCard(
        barang: items[i],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BarangDetailScreen(barangId: items[i].id!),
            ),
          );
          _load(); // stok bisa berubah dari layar detail
        },
      ),
    );
  }
}

class _BarangCard extends StatelessWidget {
  final Barang barang;
  final VoidCallback onTap;

  const _BarangCard({required this.barang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final habis = barang.stokPusat <= 0;
    final subtitle = [
      if (barang.merek != null && barang.merek!.isNotEmpty) barang.merek!,
      if (barang.tipe != null && barang.tipe!.isNotEmpty) barang.tipe!,
    ].join(' • ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: _Thumb(fotoPath: barang.fotoPath),
        title: Text(
          barang.nama,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle.isEmpty
              ? barang.kodeBarang
              : '${barang.kodeBarang} • $subtitle',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${barang.stokPusat}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: habis ? scheme.error : scheme.primary,
              ),
            ),
            Text(
              habis ? 'habis' : barang.satuan,
              style: TextStyle(
                fontSize: 11,
                color: habis ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail foto barang di daftar; placeholder ikon bila belum ada foto.
class _Thumb extends StatelessWidget {
  final String? fotoPath;

  const _Thumb({required this.fotoPath});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFoto = fotoPath != null && File(fotoPath!).existsSync();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasFoto
          ? Image.file(File(fotoPath!), fit: BoxFit.cover)
          : Icon(Icons.inventory_2_outlined,
              color: scheme.onSurfaceVariant, size: 24),
    );
  }
}
