import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

/// Total qty per transaction_item_id yang sudah pernah direfund sebelumnya
/// (dari retur-retur sebelumnya), dipakai untuk membatasi qty retur baru
/// supaya tidak melebihi qty yang dibeli.
final refundedQuantitiesProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, transactionId) async {
  final client = ref.watch(supabaseClientProvider);
  final refunds = await client.from('refunds').select('id').eq('transaction_id', transactionId);
  final refundIds = (refunds as List).map((r) => r['id'] as String).toList();
  if (refundIds.isEmpty) return {};
  final items = await client.from('refund_items').select('transaction_item_id, quantity').inFilter('refund_id', refundIds);
  final result = <String, int>{};
  for (final row in (items as List)) {
    final id = row['transaction_item_id'] as String;
    result[id] = (result[id] ?? 0) + (row['quantity'] as num).toInt();
  }
  return result;
});

/// Riwayat retur (refunds) untuk satu transaksi, untuk ditampilkan di
/// detail transaksi.
final transactionRefundsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, transactionId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('refunds')
      .select()
      .eq('transaction_id', transactionId)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class ReturnController extends StateNotifier<AsyncValue<void>> {
  ReturnController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// [items] berisi {'transaction_item_id': ..., 'quantity': ...} untuk
  /// tiap baris yang mau diretur. Validasi qty (tidak boleh melebihi qty
  /// dibeli dikurangi yang sudah pernah diretur), kembalikan stok, dan
  /// hitung nominal refund proporsional sepenuhnya ditangani RPC di DB.
  Future<String?> submitReturn({
    required String transactionId,
    required List<Map<String, dynamic>> items,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('refund_transaction_items', params: {
        'p_transaction_id': transactionId,
        'p_items': items,
        'p_reason': reason,
      });
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      final msg = e.toString();
      if (msg.contains('Hanya admin/owner')) return 'Hanya admin/owner yang boleh memproses retur.';
      if (msg.contains('sudah di-void')) return 'Transaksi ini sudah di-void, tidak bisa diretur.';
      if (msg.contains('melebihi qty')) {
        final match = RegExp(r'"(.+)": (qty refund melebihi qty.+)').firstMatch(msg);
        return match != null ? '${match.group(1)}: ${match.group(2)}' : 'Qty retur melebihi qty yang dibeli.';
      }
      return 'Gagal memproses retur: $e';
    }
  }
}

final returnControllerProvider = StateNotifierProvider<ReturnController, AsyncValue<void>>((ref) => ReturnController(ref));
