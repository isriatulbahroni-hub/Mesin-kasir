import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/promotion.dart';

/// Promo aktif dalam jendela tanggal berjalan, untuk dipilih dari daftar di
/// POS (bukan lewat kode voucher). Filter tanggal & is_active dilakukan di
/// client karena RLS promotions_select cuma is_store_staff (tidak
/// membatasi tanggal); validasi definitif tetap di RPC saat benar-benar
/// diterapkan/redeem.
final activePromotionsProvider = StreamProvider.autoDispose<List<Promotion>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) { yield []; return; }
  await for (final rows in ref.watch(supabaseClientProvider)
      .from('promotions')
      .stream(primaryKey: ['id'])
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)) {
    final now = DateTime.now();
    yield rows
        .map(Promotion.fromJson)
        .where((p) => p.isActive && p.isSupported && now.isAfter(p.startsAt) && now.isBefore(p.endsAt))
        .where((p) => p.usageLimit == null || p.usedCount < p.usageLimit!)
        .toList();
  }
});

/// Semua promo (termasuk yang sudah lewat/nonaktif), untuk layar manajemen.
final allPromotionsProvider = StreamProvider.autoDispose<List<Promotion>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) { yield []; return; }
  await for (final rows in ref.watch(supabaseClientProvider)
      .from('promotions')
      .stream(primaryKey: ['id'])
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)) {
    yield rows.map(Promotion.fromJson).toList();
  }
});

final promotionByIdProvider = FutureProvider.autoDispose.family<Promotion, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('promotions').select().eq('id', id).single();
  return Promotion.fromJson(data);
});

/// Promo yang aktif SEKARANG (tanggal+jam+hari cocok) DAN auto_apply=true -
/// dipanggil server (bukan dihitung di client) supaya jam HP kasir yang
/// salah setel gak bisa dimanfaatkan. Dipakai buat kasih tau kasir "ada
/// promo happy hour lagi jalan" tanpa customer perlu tahu kode apapun.
final activeAutomaticPromotionsProvider = FutureProvider.autoDispose<List<Promotion>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client.rpc('get_active_automatic_promotions', params: {'p_store_id': staff.storeId});
  return (data as List).map((e) => Promotion.fromJson(e as Map<String, dynamic>)).toList();
});

class PromotionController {
  PromotionController(this._ref);
  final Ref _ref;

  /// Cari promo lewat kode voucher. Melempar exception dengan pesan yang
  /// sudah ramah-pengguna kalau tidak valid/kedaluwarsa/habis kuota (RPC
  /// yang menangani semua validasi itu).
  Future<Promotion> findByCode(String code) async {
    final staff = await _ref.read(currentStaffProvider.future);
    if (staff == null) throw Exception('Sesi staff tidak ditemukan.');
    final client = _ref.read(supabaseClientProvider);
    final data = await client.rpc('find_promotion_by_code', params: {'p_store_id': staff.storeId, 'p_code': code});
    return Promotion.fromJson(data as Map<String, dynamic>);
  }

  /// Tandai promo terpakai. Dipanggil best-effort SETELAH checkout sukses —
  /// kalau ini gagal, penjualan tetap sah, cuma hitungan pemakaian promo
  /// jadi kurang presisi (lebih aman daripada menggabungkannya ke dalam
  /// checkout_transaction yang sudah kompleks & kritikal).
  Future<void> redeem(String promotionId) async {
    await _ref.read(supabaseClientProvider).rpc('redeem_promotion', params: {'p_promotion_id': promotionId});
  }

  Future<void> create({
    required String name,
    required String promotionType,
    required int value,
    int minimumPurchase = 0,
    int? maximumDiscount,
    int? usageLimit,
    String? code,
    required DateTime startsAt,
    required DateTime endsAt,
    List<int>? activeDays,
    String? activeTimeStart, // format "HH:mm:00"
    String? activeTimeEnd,
    bool autoApply = false,
  }) async {
    final staff = await _ref.read(currentStaffProvider.future);
    if (staff == null) throw Exception('Sesi staff tidak ditemukan.');
    await _ref.read(supabaseClientProvider).from('promotions').insert({
      'store_id': staff.storeId,
      'name': name.trim(),
      'promotion_type': promotionType,
      'value': value,
      'minimum_purchase': minimumPurchase,
      'maximum_discount': maximumDiscount,
      'usage_limit': usageLimit,
      'code': (code?.trim().isEmpty ?? true) ? null : code!.trim().toUpperCase(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'active_days': activeDays,
      'active_time_start': activeTimeStart,
      'active_time_end': activeTimeEnd,
      'auto_apply': autoApply,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _ref.read(supabaseClientProvider).from('promotions').update({'is_active': active}).eq('id', id);
  }
}

final promotionControllerProvider = Provider((ref) => PromotionController(ref));
