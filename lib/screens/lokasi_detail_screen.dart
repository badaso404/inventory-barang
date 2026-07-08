import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/lokasi.dart';
import '../widgets/empty_state.dart';

/// Detail lokasi/UKPD: daftar barang yang ada di lokasi ini + jumlahnya.
class LokasiDetailScreen extends StatefulWidget {
  final Lokasi lokasi;

  const LokasiDetailScreen({super.key, required this.lokasi});

  @override
  State<LokasiDetailScreen> createState() => _LokasiDetailScreenState();
}

class _LokasiDetailScreenState extends State<LokasiDetailScreen> {
  List<Map<String, dynamic>> _barang = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        await DatabaseHelper.instance.getBarangDiLokasi(widget.lokasi.id!);
    if (!mounted) return;
    setState(() {
      _barang = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lokasi;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.nama)),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.location_city,
                            color: scheme.onPrimaryContainer),
                      ),
                      title: Text(l.nama,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        [l.kodeLokasi, if (l.alamat != null) l.alamat!]
                            .join('\n'),
                      ),
                      isThreeLine: l.alamat != null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Barang di Lokasi Ini',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (_barang.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Belum ada barang di lokasi ini'),
                      ),
                    )
                  else
                    ..._barang.map(
                      (b) => Card(
                        child: ListTile(
                          title: Text(
                            b['nama'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(b['kode_barang'] as String),
                          trailing: Text(
                            '${b['jumlah']} ${b['satuan']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
