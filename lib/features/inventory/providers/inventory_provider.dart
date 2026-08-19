import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/product.dart';
import '../../../models/purchase.dart';
import '../../../models/supplier.dart';

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('suppliers')
      .select()
      .eq('store_id', staff.storeId)
      .eq('is_active', true)
      .order('name');
  return (data as List).map((e) => Supplier.fromJson(e)).toList();
});

final purchaseHistoryProvider = FutureProvider.autoDispose<List<Purchase>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('purchases')
      .select()
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => Purchase.fromJson(e)).toList();
});

/// Produk aktif milik toko (dipakai untuk pilih item saat restock/stock opname).
final inventoryProductListProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('products')
      .select()
      .eq('store_id', staff.storeId)
      .eq('is_active', true)
      .order('name');
  return (data as List).map((e) => Product.fromJson(e)).toList();
});

class InventoryController extends StateNotifier<AsyncValue<void>> {
  InventoryController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<String?> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';
      final client = _ref.read(supabaseClientProvider);
      await client.from('suppliers').insert({
        'store_id': staff.storeId,
        'name': name,
        'phone': phone,
        'address': address,
        'note': note,
      });
      _ref.invalidate(suppliersProvider);
      return null;
    } on Object catch (e) {
      return 'Gagal menyimpan supplier: $e';
    }
  }

  /// Terima barang masuk (restock) lewat RPC `receive_purchase` — atomic:
  /// nambah stok produk, update harga modal terbaru, catat purchase +
  /// stock_movements type='restock', semua dalam 1 transaksi DB.
  Future<String?> receivePurchase({
    required String? supplierId,
    required String? note,
    required List<Map<String, dynamic>> items, // [{product_id, quantity, cost_price}]
  }) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';
      if (items.isEmpty) return 'Tambahkan minimal 1 produk.';

      final client = _ref.read(supabaseClientProvider);
      await client.rpc('receive_purchase', params: {
        'p_staff_id': staff.id,
        'p_supplier_id': supplierId,
        'p_note': note,
        'p_items': items,
      });

      _ref.invalidate(purchaseHistoryProvider);
      _ref.invalidate(inventoryProductListProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }

  /// Stock opname: sesuaikan stok sistem ke hasil hitung fisik lewat RPC
  /// `apply_stock_opname` — mencatat selisih ke stock_movements type='adjustment'.
  Future<String?> applyStockOpname({
    required String? note,
    required List<Map<String, dynamic>> items, // [{product_id, counted_stock}]
  }) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';
      if (items.isEmpty) return 'Tambahkan minimal 1 produk.';

      final client = _ref.read(supabaseClientProvider);
      await client.rpc('apply_stock_opname', params: {
        'p_staff_id': staff.id,
        'p_note': note,
        'p_items': items,
      });

      _ref.invalidate(inventoryProductListProvider);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('Hanya admin/owner')) return 'Hanya admin/owner yang boleh melakukan ini.';
    return 'Gagal menyimpan: $e';
  }
}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, AsyncValue<void>>(
        (ref) => InventoryController(ref));
