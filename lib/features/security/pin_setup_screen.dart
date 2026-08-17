import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/lock_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (!RegExp(r'^[0-9]{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'PIN harus 4-6 digit angka.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'Konfirmasi PIN tidak cocok.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(supabaseClientProvider).rpc('set_staff_pin', params: {'p_pin': pin});
      ref.invalidate(hasStaffPinProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan PIN: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur PIN Kunci Layar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.emerald600),
            const SizedBox(height: 12),
            const Text(
              'PIN dipakai untuk mengunci layar kasir saat kamu tinggal sebentar, '
              'tanpa perlu logout penuh. Gunakan 4-6 digit angka yang mudah diingat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.charcoal500),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(labelText: 'PIN baru'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(labelText: 'Ulangi PIN'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
