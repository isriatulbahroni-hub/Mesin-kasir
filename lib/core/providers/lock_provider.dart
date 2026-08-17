import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_provider.dart';
import 'session_provider.dart';

/// Apakah staff yang sedang login sudah pernah mengatur PIN kunci layar.
/// autoDispose + dependensi ke currentStaffProvider supaya otomatis
/// refresh setelah staff mengatur/mengganti PIN atau ganti akun.
final hasStaffPinProvider = FutureProvider.autoDispose<bool>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return false;
  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc('has_staff_pin');
  return result as bool;
});

/// Status kunci layar aplikasi saat ini. Ini murni state lokal (bukan
/// disimpan ke server) — sesi Supabase Auth yang sudah login TIDAK
/// terpengaruh oleh kunci ini, PIN hanya menghalangi tampilan/interaksi.
class LockController extends StateNotifier<bool> {
  LockController() : super(false);

  void lock() => state = true;
  void unlock() => state = false;
}

final lockProvider = StateNotifierProvider<LockController, bool>((ref) => LockController());
