import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend facade for the POS modules added to the Supabase schema.
///
/// This class deliberately keeps business rules in RPCs/database policies;
/// Flutter only supplies identifiers and user intent.
class PosExtendedService {
  PosExtendedService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> customers(String storeId) async {
    final rows = await _client
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
    String? memberCode,
  }) async {
    final row = await _client.from('customers').insert({
      'store_id': storeId,
      'name': name.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'member_code': memberCode?.trim().isEmpty == true ? null : memberCode?.trim(),
    }).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<int> awardPoints({
    required String customerId,
    String? transactionId,
    required int points,
    required String reason,
  }) async {
    final value = await _client.rpc('award_customer_points', params: {
      'p_customer_id': customerId,
      'p_transaction_id': transactionId,
      'p_points': points,
      'p_reason': reason,
    });
    return (value as num).toInt();
  }

  Future<List<Map<String, dynamic>>> activePromotions(String storeId) async {
    final rows = await _client
        .from('promotions')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .lte('starts_at', DateTime.now().toUtc().toIso8601String())
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> requestApproval({
    required String storeId,
    required String type,
    String? recordId,
    int? amount,
    required String reason,
  }) async {
    final value = await _client.rpc('request_approval', params: {
      'p_store_id': storeId,
      'p_request_type': type,
      'p_record_id': recordId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return value as String;
  }

  Future<Map<String, dynamic>> decideApproval({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    final row = await _client.rpc('decide_approval', params: {
      'p_request_id': requestId,
      'p_approve': approve,
      'p_note': note,
    });
    return Map<String, dynamic>.from(row as Map);
  }

  Future<String> transferStock({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final value = await _client.rpc('transfer_stock', params: {
      'p_from': fromWarehouseId,
      'p_to': toWarehouseId,
      'p_items': items,
      'p_note': note,
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> lowStock(String storeId) async {
    final rows = await _client.rpc('low_stock_report', params: {
      'p_store_id': storeId,
    });
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> salesSummary({
    required String storeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc('sales_summary', params: {
      'p_store_id': storeId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? <String, dynamic>{} : list.first;
  }

  Future<List<Map<String, dynamic>>> paymentSummary({
    required String storeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc('payment_summary', params: {
      'p_store_id': storeId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Persists an idempotent offline operation locally and registers it with
  /// Supabase when a valid authenticated session is available.
  Future<String> queueOfflineOperation({
    required String deviceId,
    required String operationKey,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'offline_queue_$deviceId';
    final raw = prefs.getStringList(localKey) ?? <String>[];
    final record = <String, dynamic>{
      'operation_key': operationKey,
      'operation_type': operationType,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    raw.removeWhere((entry) {
      try {
        return (jsonDecode(entry) as Map<String, dynamic>)['operation_key'] == operationKey;
      } catch (_) {
        return false;
      }
    });
    raw.add(jsonEncode(record));
    await prefs.setStringList(localKey, raw);

    try {
      final id = await _client.rpc('create_offline_queue_item', params: {
        'p_device_id': deviceId,
        'p_operation_key': operationKey,
        'p_operation_type': operationType,
        'p_payload': payload,
      });
      return id as String;
    } on PostgrestException {
      // Local queue remains authoritative until connectivity/auth is restored.
      return operationKey;
    }
  }

  Future<List<Map<String, dynamic>>> pendingOfflineOperations(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('offline_queue_$deviceId') ?? <String>[];
    return raw.map((entry) => Map<String, dynamic>.from(jsonDecode(entry) as Map)).toList();
  }

  Future<void> removeOfflineOperation(String deviceId, String operationKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'offline_queue_$deviceId';
    final raw = prefs.getStringList(key) ?? <String>[];
    raw.removeWhere((entry) {
      try {
        return (jsonDecode(entry) as Map<String, dynamic>)['operation_key'] == operationKey;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(key, raw);
  }
}
