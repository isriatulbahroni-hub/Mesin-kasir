import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/staff.dart';
import '../../models/store.dart';
import '../../models/shift.dart';
import 'supabase_provider.dart';

/// Data staff (baris di tabel `staff`) untuk user yang sedang login.
/// Ini yang menentukan role (owner/admin/kasir) dan store_id yang dipakai
/// di seluruh query lain — SEMUA query data toko WAJIB difilter oleh
/// store_id dari sini (selain juga dijaga oleh RLS di server).
final currentStaffProvider = FutureProvider<Staff?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('staff')
      .select()
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle();

  if (data == null) return null;
  return Staff.fromJson(data);
});

final currentStoreProvider = FutureProvider<Store?>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data =
      await client.from('stores').select().eq('id', staff.storeId).single();
  return Store.fromJson(data);
});

/// Shift yang sedang aktif (belum ditutup) milik staff yang login, kalau ada.
final activeShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('shifts')
      .select()
      .eq('staff_id', staff.id)
      .isFilter('closed_at', null)
      .order('opened_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (data == null) return null;
  return Shift.fromJson(data);
});
