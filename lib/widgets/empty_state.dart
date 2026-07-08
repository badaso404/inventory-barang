import 'package:flutter/material.dart';

/// Tampilan kosong yang konsisten di seluruh app (ikon + pesan + aksi opsional).
///
/// Selalu bisa di-scroll agar tetap kompatibel dengan RefreshIndicator
/// (pull-to-refresh) meski kontennya sedikit.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 72, color: scheme.primary.withValues(alpha: 0.35)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action!),
        ],
      ],
    );
  }
}

/// Loading terpusat — spinner di tengah layar.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
