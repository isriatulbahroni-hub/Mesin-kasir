import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/lock_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  bool _checking = false;
  String? _error;

  Future<void> _submit() async {
    if (_pin.length < 4) return;
    setState(() { _checking = true; _error = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      final ok = await client.rpc('verify_staff_pin', params: {'p_pin': _pin}) as bool;
      if (ok) {
        ref.read(lockProvider.notifier).unlock();
      } else {
        setState(() => _error = 'PIN salah.');
        _pin = '';
      }
    } catch (e) {
      setState(() => _error = e.toString().contains('Terlalu banyak')
          ? 'Terlalu banyak percobaan salah. Coba lagi sebentar.'
          : 'Gagal memverifikasi PIN.');
      _pin = '';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onDigit(String d) {
    if (_checking || _pin.length >= 6) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length >= 4) {
      // Beri jeda kecil biar dot terakhir sempat kelihatan sebelum submit.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_pin.length >= 4 && mounted) _submit();
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(currentStaffProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(
                staffAsync.maybeWhen(data: (s) => s?.fullName ?? 'Kasir', orElse: () => 'Kasir'),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Masukkan PIN untuk melanjutkan', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.emerald600 : AppColors.sand300,
                  ),
                )),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: _checking
                    ? const CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald600)
                    : (_error != null ? Text(_error!, style: const TextStyle(color: AppColors.danger)) : null),
              ),
              const Spacer(),
              _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                child: Text('Bukan kamu? Keluar akun', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: AspectRatio(
            aspectRatio: 1.4,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: AppColors.surfaceElevated,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Center(
                    child: child ?? Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        );

    return Column(
      children: [
        Row(children: [key('1', onTap: () => onDigit('1')), key('2', onTap: () => onDigit('2')), key('3', onTap: () => onDigit('3'))]),
        Row(children: [key('4', onTap: () => onDigit('4')), key('5', onTap: () => onDigit('5')), key('6', onTap: () => onDigit('6'))]),
        Row(children: [key('7', onTap: () => onDigit('7')), key('8', onTap: () => onDigit('8')), key('9', onTap: () => onDigit('9'))]),
        Row(children: [
          const Expanded(child: SizedBox()),
          key('0', onTap: () => onDigit('0')),
          key('', onTap: onBackspace, child: Icon(Icons.backspace_outlined, color: AppColors.textSecondary, size: 22)),
        ]),
      ],
    );
  }
}
