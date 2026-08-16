import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// Instance client Supabase (project Kasir Pro).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

/// Stream perubahan status auth (login/logout/token refresh).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

/// User Supabase Auth yang sedang login (null kalau belum login).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => SupabaseConfig.client.auth.currentUser,
  );
});
