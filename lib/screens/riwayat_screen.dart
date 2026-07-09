import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../services/data_refresh.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/riwayat_tile.dart';

enum _TipeFilter { semua, masuk, keluar, kembali }

/// Tab Riwayat: gabungan transaksi masuk, keluar & kembali. Bisa dicari
/// (nama/kode barang) dan difilter berdasarkan tipe serta periode
/// (hari ini / bulan tertentu / rentang tanggal).
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  String _query = '';
  _TipeFilter _tipe = _TipeFilter.semua;
  DateTimeRange? _range;
  String _periodeLabel = 'Semua tanggal';

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
    final data = await DatabaseHelper.instance.getRiwayat();
    if (!mounted) return;
    setState(() {
      _all = data;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((r) {
      // Tipe
      final matchTipe = switch (_tipe) {
        _TipeFilter.semua => true,
        _TipeFilter.masuk => r['tipe'] == 'masuk',
        _TipeFilter.keluar => r['tipe'] == 'keluar',
        _TipeFilter.kembali => r['tipe'] == 'kembali',
      };
      if (!matchTipe) return false;

      // Pencarian nama / kode barang
      if (q.isNotEmpty) {
        final nama = (r['nama_barang'] as String? ?? '').toLowerCase();
        final kode = (r['kode_barang'] as String? ?? '').toLowerCase();
        if (!nama.contains(q) && !kode.contains(q)) return false;
      }

      // Periode
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

  // --- Pemilihan periode -----------------------------------------------------

  void _setPeriode(DateTimeRange? range, String label) {
    setState(() {
      _range = range;
      _periodeLabel = label;
    });
  }

  Future<void> _openPeriodeMenu() async {
    final now = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _periodeItem(ctx, Icons.all_inclusive, 'Semua tanggal',
                () => _setPeriode(null, 'Semua tanggal')),
            _periodeItem(ctx, Icons.today, 'Hari ini', () {
              final d = DateTime(now.year, now.month, now.day);
              _setPeriode(DateTimeRange(start: d, end: d), 'Hari ini');
            }),
            _periodeItem(ctx, Icons.calendar_view_month, 'Bulan ini', () {
              _setBulan(now.year, now.month);
            }),
            _periodeItem(ctx, Icons.history_toggle_off, 'Bulan lalu', () {
              final b = DateTime(now.year, now.month - 1, 1);
              _setBulan(b.year, b.month);
            }),
            _periodeItem(ctx, Icons.event_note, 'Pilih bulan…', () async {
              final picked = await _pickBulan();
              if (picked != null) _setBulan(picked.year, picked.month);
            }),
            _periodeItem(ctx, Icons.date_range, 'Rentang tanggal…', () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 1),
                initialDateRange: _range,
              );
              if (picked != null) {
                _setPeriode(
                  picked,
                  '${Format.tanggalOf(picked.start)} - '
                      '${Format.tanggalOf(picked.end)}',
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _periodeItem(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  void _setBulan(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0); // hari terakhir bulan itu
    _setPeriode(DateTimeRange(start: start, end: end),
        Format.bulanTahun(start));
  }

  /// Dialog pilih bulan & tahun.
  Future<DateTime?> _pickBulan() async {
    var year = (_range?.start.year) ?? DateTime.now().year;
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setInner(() => year--),
              ),
              Text('$year', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setInner(() => year++),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: List.generate(12, (i) {
                return OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, DateTime(year, i + 1, 1)),
                  child: Text(Format.bulanPanjang[i].substring(0, 3)),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI --------------------------------------------------------------------

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
    final adaPeriode = _range != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama / kode barang...',
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _chip('Semua', _TipeFilter.semua),
              _chip('Masuk', _TipeFilter.masuk),
              _chip('Keluar', _TipeFilter.keluar),
              _chip('Kembali', _TipeFilter.kembali),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openPeriodeMenu,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_periodeLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (adaPeriode)
                IconButton(
                  tooltip: 'Reset periode',
                  icon: const Icon(Icons.clear),
                  onPressed: () => _setPeriode(null, 'Semua tanggal'),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${items.length} transaksi',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) => RiwayatTile(row: items[i]),
          ),
        ),
      ],
    );
  }
}
