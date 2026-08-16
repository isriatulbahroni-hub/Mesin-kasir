import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';

class ShiftController extends StateNotifier<AsyncValue<void>> {
  ShiftController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<String?> openShift({required int openingCash}) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';

      final client = _ref.read(supabaseClientProvider);
      await client.from('shifts').insert({
        'store_id': staff.storeId,
        'staff_id': staff.id,
        'opening_cash': openingCash,
      });

      _ref.invalidate(activeShiftProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return 'Gagal membuka shift: $e';
    }
  }

  /// Tutup shift + hitung selisih kas.
  /// expected_cash dihitung dari opening_cash + total penjualan tunai selama shift.
  Future<String?> closeShift({
    required String shiftId,
    required int openingCash,
    required DateTime openedAt,
    required int closingCash,
  }) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';

      final client = _ref.read(supabaseClientProvider);

      // Jumlahkan transaksi tunai (completed) milik staff ini sejak shift dibuka.
      final txRows = await client
          .from('transactions')
          .select('total, payment_method, status')
          .eq('staff_id', staff.id)
          .eq('payment_method', 'tunai')
          .eq('status', 'completed')
          .gte('created_at', openedAt.toIso8601String());

      final cashSales = (txRows as List)
          .fold<int>(0, (sum, row) => sum + ((row['total'] as num).toInt()));

      final expectedCash = openingCash + cashSales;
      final difference = closingCash - expectedCash;

      await client.from('shifts').update({
        'closing_cash': closingCash,
        'expected_cash': expectedCash,
        'cash_difference': difference,
        'closed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', shiftId);

      _ref.invalidate(activeShiftProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return 'Gagal menutup shift: $e';
    }
  }
}

final shiftControllerProvider =
    StateNotifierProvider<ShiftController, AsyncValue<void>>(
        (ref) => ShiftController(ref));
