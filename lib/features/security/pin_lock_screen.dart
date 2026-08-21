import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/lock_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'pin_setup_screen.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  bool _checking = false;
  String? _error;
  Timer? _submitTimer;

  @override
  void dispose() {
    _submitTimer?.cancel();
    super.dispose();
  }

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

    // PIN bisa 4-6 digit (fleksibel), jadi TIDAK BOLEH langsung submit begitu
    // mencapai 4 digit - kalau PIN aslinya 6 digit dan user mengetik cepat,
    // submit prematur ini akan mengirim PIN yang belum lengkap (4-5 digit),
    // pasti gagal, lalu reset - persis bug yang bikin PIN kelihatan "cuma
    // kebaca 4 angka". Sekarang: batalkan timer lama tiap kali ada digit
    // baru (debounce), dan HANYA submit otomatis kalau sudah pasti maksimal
    // (6 digit, tidak mungkin ada digit lagi) atau user berhenti mengetik
    // selama 600ms (asumsi PIN-nya memang cuma 4-5 digit).
    _submitTimer?.cancel();
    if (_pin.length == 6) {
      _submit();
    } else if (_pin.length >= 4) {
      _submitTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _pin.length >= 4) _submit();
      });
    }
  }

  void _onBackspace() {
    _submitTimer?.cancel();
    if (_pin.isEmpty) return;
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
  }

  void _showForgotPinDialog() {
    final passCtrl = TextEditingController();
    bool submitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Lupa PIN?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan password akun (bukan PIN) buat verifikasi identitas kamu. '
                'Setelah itu kamu bisa atur PIN baru.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password akun'),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final email = ref.read(supabaseClientProvider).auth.currentUser?.email;
                      if (email == null || passCtrl.text.isEmpty) return;
                      setDialogState(() { submitting = true; dialogError = null; });
                      try {
                        // Re-autentikasi pakai password akun sebagai "bukti identitas"
                        // sebelum boleh mengganti PIN - supabase_flutter belum punya
                        // API khusus "verify current password", jadi signInWithPassword
                        // dipakai sebagai pengecekan yang setara (gagal kalau salah,
                        // dan aman dipanggil berulang untuk user yang sama).
                        await ref.read(supabaseClientProvider).auth.signInWithPassword(
                              email: email,
                              password: passCtrl.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                        );
                        if (result == true) {
                          ref.read(lockProvider.notifier).unlock();
                        }
                      } catch (_) {
                        setDialogState(() { submitting = false; dialogError = 'Password salah.'; });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verifikasi'),
            ),
          ],
        ),
      ),
    );
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
                onPressed: _showForgotPinDialog,
                child: Text('Lupa PIN?', style: TextStyle(color: AppColors.textSecondary)),
              ),
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
