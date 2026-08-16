import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import 'providers/cart_provider.dart';
import 'providers/pos_provider.dart';

/// Cari produk berdasarkan kode barcode/SKU. Perbandingan case-insensitive
/// dan mengabaikan spasi, karena kamera maupun scanner hardware kadang
/// menyisipkan whitespace di hasil baca.
Product? findProductByCode(List<Product> products, String code) {
  final needle = code.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final p in products) {
    if (p.sku?.trim().toLowerCase() == needle) return p;
  }
  return null;
}

/// Satu titik masuk untuk "kode terbaca -> masuk keranjang", dipakai oleh
/// scan kamera (barcode_scanner_screen) maupun scanner hardware/keyboard-wedge
/// (dipasang di pos_screen). Menyatukan logika di sini mencegah dua alur
/// scan saling berbeda perilaku (mis. validasi stok cuma ada di satu jalur).
void handleScannedCode(BuildContext context, WidgetRef ref, String rawCode) {
  final code = rawCode.trim();
  if (code.isEmpty) return;
  final products = ref.read(productsStreamProvider).valueOrNull ?? const <Product>[];
  final found = findProductByCode(products, code);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (found == null) {
    messenger.showSnackBar(SnackBar(content: Text('Barcode "$code" belum terdaftar.')));
    return;
  }
  if (found.isOutOfStock) {
    messenger.showSnackBar(SnackBar(content: Text('${found.name}: stok habis.')));
    return;
  }
  ref.read(cartProvider.notifier).addProduct(found);
  messenger.showSnackBar(SnackBar(
    content: Text('${found.name} ditambahkan ke keranjang.'),
    duration: const Duration(milliseconds: 900),
  ));
}
