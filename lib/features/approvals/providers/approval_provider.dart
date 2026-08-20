import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/approval_request.dart';

final approvalRequestsProvider = FutureProvider.autoDispose<List<ApprovalRequest>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('approval_requests')
      .select()
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)
      .limit(100);
  return (data as List).map((e) => ApprovalRequest.fromJson(e)).toList();
});

class ApprovalController extends StateNotifier<AsyncValue<void>> {
  ApprovalController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// Ajukan permintaan approval (dipanggil kasir untuk aksi sensitif yang
  /// butuh persetujuan admin/owner, mis. diskon di luar batas normal).
  Future<String?> requestApproval({
    required String requestType,
    String? recordId,
    int? amount,
    String? reason,
  }) async {
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('request_approval', params: {
        'p_store_id': staff.storeId,
        'p_request_type': requestType,
        'p_record_id': recordId,
        'p_amount': amount,
        'p_reason': reason,
      });
      _ref.invalidate(approvalRequestsProvider);
      return null;
    } on Object catch (e) {
      return 'Gagal mengajukan approval: $e';
    }
  }

  /// Setujui/tolak permintaan — cuma admin/owner (ditegakkan di RPC).
  Future<String?> decide({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('decide_approval', params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_note': note,
      });
      _ref.invalidate(approvalRequestsProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return 'Gagal memproses: $e';
    }
  }
}

final approvalControllerProvider =
    StateNotifierProvider<ApprovalController, AsyncValue<void>>((ref) => ApprovalController(ref));
