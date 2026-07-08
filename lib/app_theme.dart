import 'package:flutter/material.dart';

/// Tema Material 3 terpusat supaya tampilan konsisten di seluruh app.
/// Mengikuti identitas logo Kominfotik: oranye + hitam, latar putih.
class AppTheme {
  AppTheme._();

  /// Warna brand dari logo.
  static const Color brandOrange = Color(0xFFF5A31E); // oranye logo
  static const Color brandBlack = Color(0xFF1A1A1A); // hitam teks logo
  static const Color seed = brandOrange;

  /// Warna semantik transaksi, dipakai konsisten di seluruh app.
  static const Color masuk = Color(0xFF2E7D32); // hijau — barang masuk
  static const Color keluar = brandOrange; // oranye — barang keluar

  static ThemeData get light {
    // Pakai palet Material 3 dari seed oranye, tapi paksa primary tetap
    // oranye brand (seed oranye murni cenderung menghasilkan primary kecoklatan).
    final scheme = ColorScheme.fromSeed(
      seedColor: brandOrange,
      primary: brandOrange,
      onPrimary: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: brandBlack,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: brandBlack,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: brandOrange.withValues(alpha: 0.18),
        elevation: 3,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
}
