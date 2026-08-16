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

/// Hasil checkout: sukses berisi invoice_no.
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
        state = const AsyncData(null);
        return CheckoutResult.failure('Sesi staff tidak ditemukan. Coba login ulang.');
      }

      final activeShift = await _ref.read(activeShiftProvider.future);
      if (activeShift == null) {
        state = const AsyncData(null);
        return CheckoutResult.failure(
            'Shift kasir belum dibuka. Buka shift dulu di tab Shift sebelum transaksi.');
      }

      if (paidAmount <= 0) {
        state = const AsyncData(null);
        return CheckoutResult.failure('Nominal pembayaran harus lebih dari 0.');
      }

      final client = _ref.read(supabaseClientProvider);

      // Server authoritative: harga/nama/cost_price diambil dari products oleh
      // RPC. Client hanya mengirim product_id, quantity, dan discount.
      final itemsPayload = cart.lines
          .map((l) => {
                'product_id': l.product.id,
                'quantity': l.quantity,
                'discount': l.discount,
              })
          .toList();

      // checkout_transaction menerima ARRAY pembayaran, bukan pasangan
      // payment_method/paid_amount. Ini juga membuat split-payment kompatibel
      // dengan schema transaction_payments.
      final paymentsPayload = [
        {
          'method': method.name,
          'amount': paidAmount,
        }
      ];

      final txRow = await client.rpc('checkout_transaction', params: {
        'p_staff_id': staff.id,
        'p_shift_id': activeShift.id,
        'p_payments': paymentsPayload,
        'p_transaction_discount': cart.transactionDiscount,
        'p_note': cart.note.isEmpty ? null : cart.note,
        'p_items': itemsPayload,
      }).single();

      final transaction = Transaction.fromJson(txRow);

      _ref.read(cartProvider.notifier).clear();
      state = const AsyncData(null);
      return CheckoutResult.success(transaction.invoiceNo, transaction.id);
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return CheckoutResult.failure(_friendlyCheckoutError(e));
    }
  }
}

String _friendlyCheckoutError(Object e) {
  final msg = e.toString();
  if (msg.contains('Stok produk') && msg.contains('tidak mencukupi')) {
    return msg.replaceFirst(RegExp(r'^.*?Exception: '), '');
  }
  if (msg.contains('Shift kasir tidak valid') || msg.contains('sudah ditutup')) {
    return 'Shift sudah tidak aktif. Buka shift baru dulu.';
  }
  if (msg.contains('kurang dari total')) {
    return 'Uang dibayar kurang dari total transaksi.';
  }
  if (msg.contains('Authentication diperlukan')) {
    return 'Sesi login sudah berakhir. Silakan login ulang.';
  }
  return 'Gagal menyimpan transaksi. ${msg.replaceFirst(RegExp(r'^.*?Exception: '), '')}';
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, AsyncValue<void>>(
        (ref) => CheckoutController(ref));
