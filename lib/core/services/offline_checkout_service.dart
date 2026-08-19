import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_pos_database.dart';

class OfflineCheckoutService {
  OfflineCheckoutService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;
  final SupabaseClient _supabase;
  final _local = LocalPosDatabase.instance;

  Future<String> checkout({
    required String storeId,
    required String shiftId,
    required List<Map<String, dynamic>> items,
    required int paidAmount,
    required String paymentMethod,
    List<Map<String, dynamic>>? payments,
    required String idempotencyKey,
    int transactionDiscount = 0,
    String? customerId,
  }) async {
    final payload = <String, dynamic>{
      'store_id': storeId, 'shift_id': shiftId, 'items': items,
      'paid_amount': paidAmount, 'payment_method': paymentMethod,
      'payments': payments, 'idempotency_key': idempotencyKey,
      'transaction_discount': transactionDiscount,
      'customer_id': customerId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final result = await _supabase.rpc('checkout_transaction', params: {
        'p_store_id': storeId, 'p_shift_id': shiftId, 'p_items': items,
        'p_paid_amount': paidAmount, 'p_payment_method': paymentMethod,
        'p_payments': payments, 'p_idempotency_key': idempotencyKey,
        'p_transaction_discount': transactionDiscount,
        'p_customer_id': customerId,
      }).timeout(const Duration(seconds: 15));
      return result.toString();
    } on PostgrestException {
      // The request reached the server and was rejected (stok kurang, bayar
      // kurang, shift tidak aktif, dll). This is a real failure, not a
      // connectivity problem — must NOT be queued for silent retry.
      rethrow;
    } on AuthException {
      // Session/auth problem — surface immediately, don't queue.
      rethrow;
    } catch (_) {
      // Network/timeout failure: the request may never have reached the
      // server, so it's safe to durably queue for retry with the same
      // idempotency key.
      await _local.enqueue(key: idempotencyKey, storeId: storeId, shiftId: shiftId, payload: jsonEncode(payload));
      rethrow;
    }
  }

  Future<int> pendingCount() async => (await _local.queue()).length;

  Future<void> sync() async {
    final queue = await _local.queue();
    for (final row in queue) {
      final key = row['idempotency_key'] as String;
      try {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        await _supabase.rpc('checkout_transaction', params: {
          'p_store_id': payload['store_id'], 'p_shift_id': payload['shift_id'],
          'p_items': payload['items'], 'p_paid_amount': payload['paid_amount'],
          'p_payment_method': payload['payment_method'], 'p_payments': payload['payments'],
          'p_transaction_discount': payload['transaction_discount'] ?? 0,
          'p_customer_id': payload['customer_id'],
          // Critical: retries always reuse the original key.
          'p_idempotency_key': key,
        }).timeout(const Duration(seconds: 15));
        await _local.remove(key);
      } catch (e) {
        await _local.fail(key, e.toString());
      }
    }
  }
}
