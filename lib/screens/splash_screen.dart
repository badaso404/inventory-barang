import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/session_manager.dart';
import 'login_screen.dart';
import 'main_screen.dart';

/// Splash: tampil logo + nama app selama ~2.5 detik, lalu cek session dan
/// arahkan ke Dashboard (sudah login) atau Login (belum).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final loggedIn = await SessionManager.instance.isLoggedIn();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => loggedIn ? const MainScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Image.asset(
                'assets/images/logo.png',
                width: 320,
                fit: BoxFit.contain,
                // Fallback bila file logo belum ditaruh, agar app tak crash.
                errorBuilder: (context, error, stack) => _fallbackLogo(),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppTheme.brandOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.brandOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            size: 64,
            color: AppTheme.brandOrange,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kominfotik Jakarta Barat',
          style: TextStyle(
            color: AppTheme.brandBlack,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Stok Barang',
          style: TextStyle(color: AppTheme.brandOrange, fontSize: 16),
        ),
      ],
    );
  }
}
