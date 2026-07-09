import 'package:flutter/material.dart';

import '../database_helper.dart';

/// Form ganti password: verifikasi password lama, lalu simpan yang baru
/// (disimpan sebagai hash).
class GantiPasswordScreen extends StatefulWidget {
  final int userId;

  const GantiPasswordScreen({super.key, required this.userId});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lamaCtrl = TextEditingController();
  final _baruCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();

  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _saving = false;

  @override
  void dispose() {
    _lamaCtrl.dispose();
    _baruCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final ok = await DatabaseHelper.instance.changePassword(
        userId: widget.userId,
        oldPassword: _lamaCtrl.text,
        newPassword: _baruCtrl.text,
      );

      if (!mounted) return;

      if (!ok) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: const Text('Password lama salah'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: const Text('Password berhasil diganti'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengganti password: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _lamaCtrl,
                obscureText: _obscureLama,
                decoration: InputDecoration(
                  labelText: 'Password Lama *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureLama
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureLama = !_obscureLama),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Password lama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baruCtrl,
                obscureText: _obscureBaru,
                decoration: InputDecoration(
                  labelText: 'Password Baru *',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureBaru
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureBaru = !_obscureBaru),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password baru wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  if (v == _lamaCtrl.text) {
                    return 'Password baru harus berbeda dari yang lama';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _konfirmasiCtrl,
                obscureText: _obscureBaru,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password Baru *',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (v) => (v != _baruCtrl.text)
                    ? 'Konfirmasi tidak cocok'
                    : null,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Password Baru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
