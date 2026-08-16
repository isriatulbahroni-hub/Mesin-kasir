import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../models/transaction.dart';
import 'cart_provider.dart';

/// Daftar produk aktif milik toko yang sedang login, realtime (Supabase stream)
/// supaya perubahan stok dari perangkat lain langsung kelihatan.
final productsStreamProvider = StreamProvider.autoDispose<List<Product>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) {
    yield [];
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  final stream = client
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('store_id', staff.storeId)
      .order('name');

  await for (final rows in stream) {
    yield rows
        .map(Product.fromJson)
        .where((p) => p.isActive)
        .toList();
  }
});

final categoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('categories')
      .select()
      .eq('store_id', staff.storeId)
      .order('sort_order');
  return (data as List).map((e) => ProductCategory.fromJson(e)).toList();
});

final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);

final productSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Hasil checkout: sukses berisi invoice_no, gagal berisi pesan error.
class CheckoutResult {
  final bool success;
  final String? invoiceNo;
  final String? transactionId;
  final String? error;
  CheckoutResult.success(this.invoiceNo, this.transactionId)
      : success = true,
        error = null;
  CheckoutResult.failure(this.error)
      : success = false,
        invoiceNo = null,
        transactionId = null;
}

class CheckoutController extends StateNotifier<AsyncValue<void>> {
  CheckoutController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<CheckoutResult> checkout({
    required PaymentMethod method,
    required int paidAmount,
  }) async {
    state = const AsyncLoading();
    final cart = _ref.read(cartProvider);
    if (cart.lines.isEmpty) {
      state = const AsyncData(null);
      return CheckoutResult.failure('Keranjang masih kosong.');
    }

    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) {
        return CheckoutResult.failure('Sesi staff tidak ditemukan. Coba login ulang.');
      }

      final activeShift = await _ref.read(activeShiftProvider.future);
      if (activeShift == null) {
        return CheckoutResult.failure(
            'Shift kasir belum dibuka. Buka shift dulu di tab Shift sebelum transaksi.');
      }

      final client = _ref.read(supabaseClientProvider);

      // 1) Insert transaksi header. invoice_no & created_at di-generate trigger DB.
      final txRow = await client
          .from('transactions')
          .insert({
            'store_id': staff.storeId,
            'staff_id': staff.id,
            'subtotal': cart.subtotal,
            'discount': cart.totalDiscount,
            'tax': 0,
            'total': cart.total,
            'paid_amount': paidAmount,
            'change_amount': (paidAmount - cart.total).clamp(0, paidAmount),
            'payment_method': method.name,
            'status': 'completed',
            'note': cart.note.isEmpty ? null : cart.note,
          })
          .select()
          .single();

      final transaction = Transaction.fromJson(txRow);

      // 2) Insert item-item transaksi. Trigger DB akan otomatis potong stok
      //    produk & catat stock_movements (type='sale') per baris yang di-insert.
      final itemsPayload = cart.lines
          .map((l) => {
                'transaction_id': transaction.id,
                'product_id': l.product.id,
                'product_name': l.product.name,
                'price': l.product.sellingPrice,
                'cost_price': l.product.costPrice,
                'quantity': l.quantity,
                'discount': l.discount,
                'subtotal': l.netSubtotal,
              })
          .toList();

      await client.from('transaction_items').insert(itemsPayload);

      _ref.read(cartProvider.notifier).clear();
      state = const AsyncData(null);
      return CheckoutResult.success(transaction.invoiceNo, transaction.id);
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutResult.failure('Gagal menyimpan transaksi: $e');
    }
  }
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, AsyncValue<void>>(
        (ref) => CheckoutController(ref));
