import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/customer.dart';

final customersStreamProvider = StreamProvider.autoDispose<List<Customer>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) { yield []; return; }
  await for (final rows in ref.watch(supabaseClientProvider)
      .from('customers')
      .stream(primaryKey: ['id'])
      .eq('store_id', staff.storeId)
      .order('name')) {
    yield rows.where((r) => r['is_active'] == true).map(Customer.fromJson).toList();
  }
});

final customerPointLedgerProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('customer_point_ledger')
      .select()
      .eq('customer_id', customerId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

final customerByIdProvider = FutureProvider.autoDispose.family<Customer, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('customers').select().eq('id', id).single();
  return Customer.fromJson(data);
});

class CustomerController {
  CustomerController(this._ref);
  final Ref _ref;

  Future<void> create({required String name, String? phone, String? email, String? memberCode}) async {
    final staff = await _ref.read(currentStaffProvider.future);
    if (staff == null) throw Exception('Sesi staff tidak ditemukan.');
    await _ref.read(supabaseClientProvider).from('customers').insert({
      'store_id': staff.storeId,
      'name': name.trim(),
      'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
      'email': (email?.trim().isEmpty ?? true) ? null : email!.trim(),
      'member_code': (memberCode?.trim().isEmpty ?? true) ? null : memberCode!.trim(),
    });
  }

  Future<void> update(String id, {required String name, String? phone, String? email, String? memberCode}) async {
    await _ref.read(supabaseClientProvider).from('customers').update({
      'name': name.trim(),
      'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
      'email': (email?.trim().isEmpty ?? true) ? null : email!.trim(),
      'member_code': (memberCode?.trim().isEmpty ?? true) ? null : memberCode!.trim(),
    }).eq('id', id);
  }

  Future<void> deactivate(String id) async {
    await _ref.read(supabaseClientProvider).from('customers').update({'is_active': false}).eq('id', id);
  }
}

final customerControllerProvider = Provider((ref) => CustomerController(ref));
