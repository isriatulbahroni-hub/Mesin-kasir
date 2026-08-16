import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

class TransactionActionController extends StateNotifier<AsyncValue<void>> {
  TransactionActionController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// [newStatus] harus 'void' atau 'refunded'. Logic (cek role admin/owner,
  /// kembalikan stok, catat stock_movements) sepenuhnya ditangani RPC di DB
  /// secara atomic — lihat fungsi `void_or_refund_transaction`.
  Future<String?> voidOrRefund({
    required String transactionId,
    required String newStatus,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('void_or_refund_transaction', params: {
        'p_transaction_id': transactionId,
        'p_new_status': newStatus,
        'p_reason': reason,
      });
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('Hanya admin/owner')) return 'Hanya admin/owner yang boleh void/refund.';
    if (msg.contains('sudah berstatus')) return 'Transaksi ini sudah diproses sebelumnya.';
    return 'Gagal memproses: $e';
  }
}

final transactionActionControllerProvider =
    StateNotifierProvider<TransactionActionController, AsyncValue<void>>(
        (ref) => TransactionActionController(ref));
