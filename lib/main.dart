import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const StokBarangApp());
}

class StokBarangApp extends StatelessWidget {
  const StokBarangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StokBarang',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
