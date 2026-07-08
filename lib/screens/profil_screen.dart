import 'package:flutter/material.dart';

import '../services/session_manager.dart';
import '../widgets/empty_state.dart';
import 'login_screen.dart';

/// Tab Profil: menampilkan data user yang login + tombol logout.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = _user;

    if (user == null) {
      return const LoadingView();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: scheme.primary,
            child: Text(
              user.namaLengkap.isNotEmpty
                  ? user.namaLengkap[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.namaLengkap,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '@${user.username}',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Role'),
                trailing: Text(user.role),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('User ID'),
                trailing: Text('${user.id}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }
}
