import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';

class CashMovement {
  final String id;
  final String type; // cash_in | cash_out | expense
  final int amount;
  final String? note;
  final DateTime createdAt;

  CashMovement({required this.id, required this.type, required this.amount, this.note, required this.createdAt});

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toInt(),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get label => switch (type) {
        'cash_in' => 'Kas Masuk',
        'cash_out' => 'Kas Keluar',
        'expense' => 'Pengeluaran',
        _ => type,
      };
}

/// Daftar mutasi kas (cash in/out/expense) untuk shift yang sedang aktif.
final cashMovementsProvider =
    FutureProvider.autoDispose.family<List<CashMovement>, String>((ref, shiftId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('cash_movements')
      .select()
      .eq('shift_id', shiftId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => CashMovement.fromJson(e)).toList();
});

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

  /// Catat kas masuk/keluar/pengeluaran selama shift berjalan lewat RPC
  /// `add_cash_movement` — ikut dihitung server-side saat shift ditutup
  /// (lihat `close_shift`: expected_cash = modal + penjualan tunai + kas
  /// masuk − kas keluar − pengeluaran).
  Future<String?> addCashMovement({
    required String shiftId,
    required String type,
    required int amount,
    String? note,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('add_cash_movement', params: {
        'p_shift_id': shiftId,
        'p_type': type,
        'p_amount': amount,
        'p_note': note,
      });
      _ref.invalidate(cashMovementsProvider(shiftId));
      return null;
    } on Object catch (e) {
      return _friendly(e, 'mencatat kas');
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
    if (msg.contains('tidak berhak')) return 'Kamu tidak berhak untuk shift ini.';
    if (msg.contains('lebih dari 0')) return 'Nominal harus lebih dari 0.';
    return 'Gagal $action: $e';
  }
}

final shiftControllerProvider =
    StateNotifierProvider<ShiftController, AsyncValue<void>>(
        (ref) => ShiftController(ref));
