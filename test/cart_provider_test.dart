import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_pro/features/pos/providers/cart_provider.dart';
import 'package:kasir_pro/models/product.dart';

Product _fakeProduct({
  String id = 'p1',
  required int sellingPrice,
  int costPrice = 1000,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    storeId: 'store-1',
    name: 'Produk Tes',
    sellingPrice: sellingPrice,
    costPrice: costPrice,
    lowStockThreshold: 5,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CartLine', () {
    test('grossSubtotal = harga x qty', () {
      final line = CartLine(product: _fakeProduct(sellingPrice: 15000), quantity: 3);
      expect(line.grossSubtotal, 45000);
    });

    test('netSubtotal mengurangi diskon per-baris', () {
      final line = CartLine(product: _fakeProduct(sellingPrice: 15000), quantity: 3, discount: 5000);
      expect(line.netSubtotal, 40000);
    });

    test('netSubtotal tidak boleh negatif walau diskon lebih besar dari subtotal', () {
      final line = CartLine(product: _fakeProduct(sellingPrice: 10000), quantity: 1, discount: 999999);
      expect(line.netSubtotal, 0);
    });
  });

  group('CartState', () {
    test('itemCount, subtotal, dan total dihitung benar untuk multi-item + diskon', () {
      final state = CartState(
        lines: [
          CartLine(product: _fakeProduct(id: 'p1', sellingPrice: 10000), quantity: 2), // 20000
          CartLine(product: _fakeProduct(id: 'p2', sellingPrice: 5000), quantity: 3, discount: 2000), // 15000-2000=13000
        ],
        transactionDiscount: 3000,
      );

      expect(state.itemCount, 5);
      expect(state.subtotal, 35000); // 20000 + 15000 (gross, sebelum diskon)
      expect(state.lineDiscountTotal, 2000);
      expect(state.totalDiscount, 5000); // 2000 (per-line) + 3000 (transaksi)
      expect(state.total, 30000); // 35000 - 5000
    });

    test('total tidak boleh negatif walau semua diskon digabung melebihi subtotal', () {
      final state = CartState(
        lines: [CartLine(product: _fakeProduct(sellingPrice: 10000), quantity: 1)],
        transactionDiscount: 999999,
      );
      expect(state.total, 0);
    });

    test('cart kosong: semua nilai nol', () {
      const state = CartState();
      expect(state.itemCount, 0);
      expect(state.subtotal, 0);
      expect(state.total, 0);
    });
  });
}
