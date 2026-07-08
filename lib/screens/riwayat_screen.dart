import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../services/data_refresh.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/riwayat_tile.dart';

enum _TipeFilter { semua, masuk, keluar }

/// Tab Riwayat: gabungan transaksi masuk & keluar, urut terbaru,
/// bisa difilter berdasarkan tipe dan rentang tanggal.
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  _TipeFilter _tipe = _TipeFilter.semua;
  DateTimeRange? _range;

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
    final data = await DatabaseHelper.instance.getRiwayat();
    if (!mounted) return;
    setState(() {
      _all = data;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    return _all.where((r) {
      final matchTipe = switch (_tipe) {
        _TipeFilter.semua => true,
        _TipeFilter.masuk => r['tipe'] == 'masuk',
        _TipeFilter.keluar => r['tipe'] == 'keluar',
      };
      if (!matchTipe) return false;

      if (_range != null) {
        final d = DateTime.tryParse(r['tanggal'] as String);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        final start = DateTime(
            _range!.start.year, _range!.start.month, _range!.start.day);
        final end =
            DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filters(),
        Expanded(
          child: _loading
              ? const LoadingView()
              : RefreshIndicator(onRefresh: _load, child: _buildList()),
        ),
      ],
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              _chip('Semua', _TipeFilter.semua),
              const SizedBox(width: 8),
              _chip('Masuk', _TipeFilter.masuk),
              const SizedBox(width: 8),
              _chip('Keluar', _TipeFilter.keluar),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _range == null
                        ? 'Semua tanggal'
                        : '${Format.tanggalOf(_range!.start)} - '
                            '${Format.tanggalOf(_range!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Reset tanggal',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _range = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _TipeFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _tipe == value,
      onSelected: (_) => setState(() => _tipe = value),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        message: _all.isEmpty
            ? 'Belum ada transaksi.'
            : 'Tidak ada transaksi pada filter ini.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) => RiwayatTile(row: items[i]),
    );
  }
}
