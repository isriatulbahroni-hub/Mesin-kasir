import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineSyncService {
  static const _queueKey = 'offline_checkout_queue_v1';
  static const _productsPrefix = 'offline_products_';

  final SupabaseClient client;
  OfflineSyncService(this.client);

  Future<void> cacheProducts(String storeId, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_productsPrefix$storeId', jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> cachedProducts(String storeId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_productsPrefix$storeId');
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> enqueueCheckout(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _readQueue(prefs);
    items.add(payload);
    await prefs.setString(_queueKey, jsonEncode(items));
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _readQueue(prefs).length;
  }

  Future<List<String>> syncPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);
    final failed = <Map<String, dynamic>>[];
    final errors = <String>[];

    for (final item in queue) {
      try {
        await client.rpc('checkout_transaction', params: {
          'p_staff_id': item['p_staff_id'],
          'p_shift_id': item['p_shift_id'],
          'p_payments': item['p_payments'],
          'p_transaction_discount': item['p_transaction_discount'] ?? 0,
          'p_note': item['p_note'],
          'p_items': item['p_items'],
        }).single();
      } catch (e) {
        failed.add(item);
        errors.add('${item['local_id']}: $e');
      }
    }

    await prefs.setString(_queueKey, jsonEncode(failed));
    return errors;
  }

  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
