import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<String?> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.auth.signInWithPassword(email: email, password: password);
      state = const AsyncData(null);
      return null; // sukses
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendlyError(e);
    }
  }

  Future<void> signOut() async {
    final client = _ref.read(supabaseClientProvider);
    await client.auth.signOut();
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu.';
    }
    if (msg.contains('network')) {
      return 'Koneksi internet bermasalah. Coba lagi.';
    }
    return 'Gagal login: $e';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
        (ref) => AuthController(ref));
