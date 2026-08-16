import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineCheckoutService {
  OfflineCheckoutService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;
  static const _queueKey = 'offline_checkout_queue_v2';
  final SupabaseClient _supabase;

  String _newIdempotencyKey() => '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_supabase.auth.currentUser?.id ?? 'device'}';

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<String> checkout({
    required String storeId,
    required String shiftId,
    required List<Map<String, dynamic>> items,
    required int paidAmount,
    required String paymentMethod,
    List<Map<String, dynamic>>? payments,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    final payload = <String, dynamic>{
      'store_id': storeId, 'shift_id': shiftId, 'items': items,
      'paid_amount': paidAmount, 'payment_method': paymentMethod,
      'payments': payments, 'idempotency_key': key,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final result = await _supabase.rpc('checkout_transaction', params: {
        'p_store_id': storeId, 'p_shift_id': shiftId, 'p_items': items,
        'p_paid_amount': paidAmount, 'p_payment_method': paymentMethod,
        'p_payments': payments, 'p_idempotency_key': key,
      }).timeout(const Duration(seconds: 15));
      return result as String;
    } catch (_) {
      final queue = await _readQueue();
      if (!queue.any((e) => e['idempotency_key'] == key)) {
        queue.add(payload);
        await _writeQueue(queue);
      }
      rethrow;
    }
  }

  Future<int> pendingCount() async => (await _readQueue()).length;

  Future<void> sync() async {
    final queue = await _readQueue();
    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        await _supabase.rpc('checkout_transaction', params: {
          'p_store_id': item['store_id'], 'p_shift_id': item['shift_id'],
          'p_items': item['items'], 'p_paid_amount': item['paid_amount'],
          'p_payment_method': item['payment_method'], 'p_payments': item['payments'],
          'p_idempotency_key': item['idempotency_key'],
        }).timeout(const Duration(seconds: 15));
      } catch (_) { remaining.add(item); }
    }
    await _writeQueue(remaining);
  }
}
