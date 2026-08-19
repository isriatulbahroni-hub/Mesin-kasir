import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/offline_checkout_service.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import 'cart_provider.dart';

final productsStreamProvider = StreamProvider.autoDispose<List<Product>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) { yield []; return; }
  await for (final rows in ref.watch(supabaseClientProvider).from('products').stream(primaryKey: ['id']).eq('store_id', staff.storeId).order('name')) {
    yield rows.map(Product.fromJson).where((p) => p.isActive).toList();
  }
});

final categoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final data = await ref.watch(supabaseClientProvider).from('categories').select().eq('store_id', staff.storeId).order('sort_order');
  return (data as List).map((e) => ProductCategory.fromJson(e)).toList();
});

final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);
final productSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class CheckoutResult {
  final bool success;
  final bool queued;
  final String? invoiceNo;
  final String? transactionId;
  final String? error;
  CheckoutResult.success(this.invoiceNo, this.transactionId) : success=true, queued=false, error=null;
  CheckoutResult.queued() : success=true, queued=true, invoiceNo=null, transactionId=null, error=null;
  CheckoutResult.failure(this.error) : success=false, queued=false, invoiceNo=null, transactionId=null;
}

class CheckoutController extends StateNotifier<AsyncValue<void>> {
  CheckoutController(this._ref) : super(const AsyncData(null));
  final Ref _ref;
  final _uuid = const Uuid();

  Future<CheckoutResult> checkout({
    required PaymentMethod method,
    required int paidAmount,
    List<Map<String, dynamic>>? splitPayments,
  }) async {
    state = const AsyncLoading();
    final cart = _ref.read(cartProvider);
    if (cart.lines.isEmpty) return CheckoutResult.failure('Keranjang masih kosong.');
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return CheckoutResult.failure('Sesi staff tidak ditemukan.');
      final shift = await _ref.read(activeShiftProvider.future);
      if (shift == null) return CheckoutResult.failure('Shift kasir belum dibuka.');

      final payments = splitPayments ?? [{'method': method.name, 'amount': paidAmount}];
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + (p['amount'] as int));
      if (totalPaid <= 0) return CheckoutResult.failure('Nominal pembayaran harus lebih dari 0.');

      final items = cart.lines.map((l) => {'product_id': l.product.id, 'quantity': l.quantity, 'discount': l.discount}).toList();
      final key = _uuid.v4();
      final service = OfflineCheckoutService(client: _ref.read(supabaseClientProvider));
      try {
        final txId = await service.checkout(storeId: staff.storeId, shiftId: shift.id, items: items, paidAmount: totalPaid, paymentMethod: method.name, payments: payments, idempotencyKey: key, transactionDiscount: cart.transactionDiscount, customerId: cart.customerId);
        String? invoiceNo;
        try {
          final row = await _ref.read(supabaseClientProvider).from('transactions').select('invoice_no').eq('id', txId).maybeSingle();
          invoiceNo = row?['invoice_no'] as String?;
        } catch (_) {
          // Best effort only — the dialog falls back to showing just the transaction id.
        }
        _ref.read(cartProvider.notifier).clear();
        state = const AsyncData(null);
        return CheckoutResult.success(invoiceNo, txId);
      } on PostgrestException catch (e, st) {
        // Server rejected the transaction (stok kurang, bayar kurang, dll).
        // This is a real failure — must not be reported as queued/success.
        state = AsyncError(e, st);
        return CheckoutResult.failure(_friendlyCheckoutError(e));
      } on AuthException catch (e, st) {
        state = AsyncError(e, st);
        return CheckoutResult.failure(_friendlyCheckoutError(e));
      } catch (_) {
        // A timeout/connectivity failure is not a failed sale: the exact
        // key/payload is durably queued by OfflineCheckoutService.
        _ref.read(cartProvider.notifier).clear();
        state = const AsyncData(null);
        return CheckoutResult.queued();
      }
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return CheckoutResult.failure(_friendlyCheckoutError(e));
    }
  }
}

String _friendlyCheckoutError(Object e) {
  final msg = e.toString();
  if (msg.contains('Insufficient stock') || msg.contains('Stok')) return 'Stok produk tidak mencukupi.';
  if (msg.contains('Shift')) return 'Shift sudah tidak aktif. Buka shift baru dulu.';
  if (msg.contains('Insufficient payment') || msg.contains('kurang')) return 'Uang dibayar kurang dari total transaksi.';
  if (msg.contains('Authentication')) return 'Sesi login sudah berakhir. Silakan login ulang.';
  return 'Gagal menyimpan transaksi. ${msg.replaceFirst(RegExp(r'^.*?Exception: '), '')}';
}

final checkoutControllerProvider = StateNotifierProvider<CheckoutController, AsyncValue<void>>((ref) => CheckoutController(ref));
