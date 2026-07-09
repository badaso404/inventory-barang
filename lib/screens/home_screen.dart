import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../database_helper.dart';
import '../services/data_refresh.dart';
import '../services/session_manager.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/riwayat_tile.dart';
import 'barang_kembali_screen.dart';
import 'barang_keluar_screen.dart';
import 'barang_masuk_screen.dart';
import 'wilayah_screen.dart';

/// Tab Home / Dashboard: ringkasan angka, shortcut fitur, dan aktivitas terkini.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DashboardStats? _stats;
  List<Map<String, dynamic>> _recent = [];
  String _nama = '';
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
    final now = DateTime.now();
    final awalBulan = DateTime(now.year, now.month, 1);
    final stats =
        await DatabaseHelper.instance.getDashboardStats(sejak: awalBulan);
    final recent = await DatabaseHelper.instance.getRiwayat(limit: 5);
    final user = await SessionManager.instance.currentUser();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _recent = recent;
      _nama = user?.namaLengkap ?? '';
      _loading = false;
    });
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView();
    }
    final s = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_nama.isNotEmpty) ...[
            Text(
              'Halo, $_nama 👋',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan bulan ${Format.bulanTahun(DateTime.now())}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                icon: Icons.category_outlined,
                color: Colors.indigo,
                label: 'Jenis Barang',
                value: '${s.jenisBarang}',
              ),
              _StatCard(
                icon: Icons.warehouse_outlined,
                color: Colors.teal,
                label: 'Total Stok Pusat',
                value: '${s.totalStokPusat}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.arrow_downward,
                    color: AppTheme.masuk,
                    label: 'Masuk',
                    value: '${s.totalMasuk}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.arrow_upward,
                    color: AppTheme.keluar,
                    label: 'Keluar',
                    value: '${s.totalKeluar}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.keyboard_return,
                    color: AppTheme.kembali,
                    label: 'Kembali',
                    value: '${s.totalKembali}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aksi Cepat',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Shortcut(
                icon: Icons.add_box_outlined,
                color: AppTheme.masuk,
                label: 'Masuk',
                onTap: () => _openAndRefresh(const BarangMasukScreen()),
              ),
              _Shortcut(
                icon: Icons.local_shipping_outlined,
                color: AppTheme.keluar,
                label: 'Keluar',
                onTap: () => _openAndRefresh(const BarangKeluarScreen()),
              ),
              _Shortcut(
                icon: Icons.keyboard_return,
                color: AppTheme.kembali,
                label: 'Kembali',
                onTap: () => _openAndRefresh(const BarangKembaliScreen()),
              ),
              _Shortcut(
                icon: Icons.location_city_outlined,
                color: Colors.blue.shade700,
                label: 'Wilayah',
                onTap: () => _openAndRefresh(const WilayahScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Aktivitas Terkini',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (_recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada aktivitas')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: RiwayatTile(row: _recent[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
        ),
      ),
    );
  }
}
