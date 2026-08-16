import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/product.dart';
import 'cart_provider.dart';
import 'pos_provider.dart';

/// Ringkasan satu transaksi yang ditahan (hold), cukup untuk ditampilkan di
/// daftar tanpa perlu ambil ulang data produk.
class HeldCartSummary {
  final String id;
  final String? label;
  final DateTime createdAt;
  final int itemCount;
  final int total;

  const HeldCartSummary({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.itemCount,
    required this.total,
  });

  factory HeldCartSummary.fromRow(Map<String, dynamic> row) {
    final items = (row['items'] as List).cast<Map<String, dynamic>>();
    final qty = items.fold<int>(0, (sum, i) => sum + (i['quantity'] as num).toInt());
    final gross = items.fold<int>(0, (sum, i) => sum + (i['price'] as num).toInt() * (i['quantity'] as num).toInt());
    final discount = items.fold<int>(0, (sum, i) => sum + ((i['discount'] as num?)?.toInt() ?? 0)) + ((row['transaction_discount'] as num?)?.toInt() ?? 0);
    return HeldCartSummary(
      id: row['id'] as String,
      label: row['label'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      itemCount: qty,
      total: (gross - discount).clamp(0, gross),
    );
  }
}

final heldCartsProvider = StreamProvider.autoDispose<List<HeldCartSummary>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) { yield []; return; }
  await for (final rows in ref.watch(supabaseClientProvider).from('held_carts').stream(primaryKey: ['id']).eq('store_id', staff.storeId).order('created_at')) {
    yield rows.map(HeldCartSummary.fromRow).toList().reversed.toList();
  }
});

class HeldCartController {
  HeldCartController(this._ref);
  final Ref _ref;

  /// Simpan keranjang saat ini sebagai transaksi tertahan, lalu kosongkan
  /// keranjang aktif supaya kasir bisa mulai transaksi baru.
  Future<void> hold({String? label}) async {
    final cart = _ref.read(cartProvider);
    if (cart.lines.isEmpty) return;
    final staff = await _ref.read(currentStaffProvider.future);
    if (staff == null) throw Exception('Sesi staff tidak ditemukan.');
    final shift = await _ref.read(activeShiftProvider.future);
    final items = cart.lines
        .map((l) => {
              'product_id': l.product.id,
              'product_name': l.product.name,
              'price': l.product.sellingPrice,
              'quantity': l.quantity,
              'discount': l.discount,
            })
        .toList();
    await _ref.read(supabaseClientProvider).from('held_carts').insert({
      'store_id': staff.storeId,
      'shift_id': shift?.id,
      'staff_id': staff.id,
      'label': (label != null && label.trim().isNotEmpty) ? label.trim() : null,
      'items': items,
      'transaction_discount': cart.transactionDiscount,
    });
    _ref.read(cartProvider.notifier).clear();
  }

  /// Ambil kembali transaksi tertahan ke keranjang aktif. Harga & stok
  /// produk diambil ulang dari katalog terkini (bukan dari snapshot lama)
  /// supaya tidak berjualan dengan harga/stok yang sudah kedaluwarsa.
  /// Mengembalikan daftar nama produk yang sudah tidak tersedia lagi (jika ada).
  Future<List<String>> resume(String heldCartId) async {
    final row = await _ref.read(supabaseClientProvider).from('held_carts').select().eq('id', heldCartId).single();
    final items = (row['items'] as List).cast<Map<String, dynamic>>();
    final products = _ref.read(productsStreamProvider).valueOrNull ?? const <Product>[];
    final byId = {for (final p in products) p.id: p};

    final lines = <CartLine>[];
    final missing = <String>[];
    for (final item in items) {
      final product = byId[item['product_id']];
      if (product == null) {
        missing.add(item['product_name'] as String? ?? 'Produk');
        continue;
      }
      final storedQty = (item['quantity'] as num).toInt();
      final qty = (product.stock != null && product.stock! < storedQty) ? (product.stock! < 1 ? 1 : product.stock!) : storedQty;
      lines.add(CartLine(product: product, quantity: qty, discount: (item['discount'] as num?)?.toInt() ?? 0));
    }

    _ref.read(cartProvider.notifier).replaceAll(
          lines: lines,
          transactionDiscount: (row['transaction_discount'] as num?)?.toInt() ?? 0,
        );
    await _ref.read(supabaseClientProvider).from('held_carts').delete().eq('id', heldCartId);
    return missing;
  }

  Future<void> discard(String heldCartId) async {
    await _ref.read(supabaseClientProvider).from('held_carts').delete().eq('id', heldCartId);
  }
}

final heldCartControllerProvider = Provider((ref) => HeldCartController(ref));
