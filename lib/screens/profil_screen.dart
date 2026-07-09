import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/session_manager.dart';
import '../widgets/empty_state.dart';
import 'ganti_password_screen.dart';
import 'login_screen.dart';

/// Tab Profil: identitas user login, info akun, dan aksi (ganti password,
/// tentang aplikasi, logout).
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  SessionUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await SessionManager.instance.currentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin logout dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _tentangAplikasi() {
    showAboutDialog(
      context: context,
      applicationName: 'Kominfotik Jakarta Barat',
      applicationVersion: 'Stok Barang • v1.0.0',
      applicationIcon: const Icon(Icons.inventory_2_rounded,
          color: AppTheme.brandOrange, size: 40),
      children: const [
        SizedBox(height: 8),
        Text(
          'Aplikasi manajemen inventory barang: stok terpusat di gudang '
          'pusat lalu didistribusikan ke lokasi/UKPD.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const LoadingView();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(user),
        const SizedBox(height: 16),
        _sectionLabel('Informasi Akun'),
        _infoCard(user),
        const SizedBox(height: 16),
        _sectionLabel('Pengaturan'),
        _menuCard(),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'StokBarang v1.0.0',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Bagian-bagian UI ------------------------------------------------------

  Widget _header(SessionUser user) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandOrange, Color(0xFFE07C00)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white,
            child: Text(
              user.namaLengkap.isNotEmpty
                  ? user.namaLengkap[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 40,
                color: AppTheme.brandOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.namaLengkap,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _infoCard(SessionUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          children: [
            _infoTile(Icons.person_outline, 'Nama Lengkap', user.namaLengkap),
            const Divider(height: 1),
            _infoTile(Icons.alternate_email, 'Username', user.username),
            const Divider(height: 1),
            _infoTile(Icons.badge_outlined, 'Role', user.role),
            const Divider(height: 1),
            _infoTile(Icons.tag, 'User ID', '${user.id}'),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _menuCard() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.lock_outline, color: scheme.primary),
              title: const Text('Ganti Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final u = _user;
                if (u == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GantiPasswordScreen(userId: u.id),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.info_outline, color: scheme.primary),
              title: const Text('Tentang Aplikasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _tentangAplikasi,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Logout',
                  style: TextStyle(color: scheme.error)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
