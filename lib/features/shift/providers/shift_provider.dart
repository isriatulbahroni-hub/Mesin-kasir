import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';

class ShiftController extends StateNotifier<AsyncValue<void>> {
  ShiftController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// Buka shift lewat RPC `open_shift` — server yang memastikan staff valid
  /// dan belum ada shift lain yang masih terbuka (dijaga juga oleh unique
  /// index parsial `uq_shifts_one_open_per_staff` di DB).
  Future<String?> openShift({required int openingCash}) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';

      final client = _ref.read(supabaseClientProvider);
      await client.rpc('open_shift', params: {
        'p_staff_id': staff.id,
        'p_opening_cash': openingCash,
      });

      _ref.invalidate(activeShiftProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e, 'membuka');
    }
  }

  /// Tutup shift lewat RPC `close_shift` — expected_cash & cash_difference
  /// dihitung SERVER-SIDE dari transaksi yang shift_id-nya cocok dengan shift
  /// ini persis (bukan lagi tebak-tebakan staff_id + rentang waktu), jadi
  /// tidak mungkin salah hitung transaksi dari shift lain.
  Future<String?> closeShift({
    required String shiftId,
    required int closingCash,
  }) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('close_shift', params: {
        'p_shift_id': shiftId,
        'p_closing_cash': closingCash,
      });

      _ref.invalidate(activeShiftProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e, 'menutup');
    }
  }

  String _friendly(Object e, String action) {
    final msg = e.toString();
    if (msg.contains('masih punya shift')) return 'Kamu masih punya shift yang belum ditutup.';
    if (msg.contains('tidak ditemukan atau sudah ditutup')) return 'Shift ini sudah ditutup sebelumnya.';
    if (msg.contains('tidak berhak')) return 'Kamu tidak berhak menutup shift ini.';
    return 'Gagal $action shift: $e';
  }
}

final shiftControllerProvider =
    StateNotifierProvider<ShiftController, AsyncValue<void>>(
        (ref) => ShiftController(ref));
