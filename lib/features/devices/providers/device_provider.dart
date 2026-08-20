import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/device.dart';

const _deviceKeyPrefName = 'device_key_v1';

/// device_key persisten per-instalasi (disimpan di SharedPreferences, beda
/// dari device_id Android/iOS asli — cukup buat identifikasi instalasi app
/// ini di device tsb, tidak perlu izin khusus).
Future<String> _getOrCreateDeviceKey() async {
  final prefs = await SharedPreferences.getInstance();
  var key = prefs.getString(_deviceKeyPrefName);
  if (key == null) {
    key = const Uuid().v4();
    await prefs.setString(_deviceKeyPrefName, key);
  }
  return key;
}

final deviceListProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('devices')
      .select()
      .eq('store_id', staff.storeId)
      .order('last_seen_at', ascending: false);
  return (data as List).map((e) => Device.fromJson(e)).toList();
});

/// device_key milik instalasi app yang sedang jalan sekarang (buat highlight
/// "Device Ini" di daftar).
final currentDeviceKeyProvider = FutureProvider<String>((ref) => _getOrCreateDeviceKey());

class DeviceController extends StateNotifier<AsyncValue<void>> {
  DeviceController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// Daftarkan (atau perbarui last_seen_at) device yang sedang dipakai. Aman
  /// dipanggil berkali-kali — upsert berdasarkan device_key.
  Future<String?> registerOrTouchThisDevice({String? customName}) async {
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';

      final deviceKey = await _getOrCreateDeviceKey();
      final client = _ref.read(supabaseClientProvider);

      final existing = await client
          .from('devices')
          .select('id')
          .eq('device_key', deviceKey)
          .eq('store_id', staff.storeId)
          .maybeSingle();

      final platform = Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
              ? 'iOS'
              : Platform.operatingSystem;

      if (existing == null) {
        await client.from('devices').insert({
          'store_id': staff.storeId,
          'staff_id': staff.id,
          'device_key': deviceKey,
          'device_name': customName ?? '$platform - ${staff.fullName}',
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client.from('devices').update({
          'staff_id': staff.id,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          if (customName != null) 'device_name': customName,
        }).eq('id', existing['id'] as String);
      }

      _ref.invalidate(deviceListProvider);
      return null;
    } on Object catch (e) {
      return 'Gagal mendaftarkan device: $e';
    }
  }

  /// Cabut akses device (mis. HP hilang/dijual) — cuma admin/owner (dijaga RLS).
  Future<String?> revokeDevice(String deviceId) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('devices')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', deviceId);
      _ref.invalidate(deviceListProvider);
      return null;
    } on Object catch (e) {
      return 'Gagal mencabut akses device: $e';
    }
  }
}

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, AsyncValue<void>>((ref) => DeviceController(ref));
