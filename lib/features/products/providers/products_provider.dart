import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/product.dart';

final productByIdProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('products').select().eq('id', id).maybeSingle();
  if (data == null) return null;
  return Product.fromJson(data);
});

class ProductFormController extends StateNotifier<AsyncValue<void>> {
  ProductFormController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<String?> save({
    String? id,
    required String name,
    String? sku,
    String? categoryId,
    required int sellingPrice,
    required int costPrice,
    int? stock,
    required int lowStockThreshold,
    String? photoUrl,
  }) async {
    state = const AsyncLoading();
    try {
      final staff = await _ref.read(currentStaffProvider.future);
      if (staff == null) return 'Sesi staff tidak ditemukan.';

      final client = _ref.read(supabaseClientProvider);
      final payload = {
        'store_id': staff.storeId,
        'category_id': categoryId,
        'name': name,
        'sku': sku,
        'photo_url': photoUrl,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'stock': stock,
        'low_stock_threshold': lowStockThreshold,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (id == null) {
        await client.from('products').insert(payload);
      } else {
        await client.from('products').update(payload).eq('id', id);
      }

      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = AsyncError(e, StackTrace.current);
      return 'Gagal menyimpan produk: $e';
    }
  }

  Future<String?> setActive(String id, bool isActive) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('products').update({'is_active': isActive}).eq('id', id);
      return null;
    } on Object catch (e) {
      return 'Gagal memperbarui produk: $e';
    }
  }
}

final productFormControllerProvider =
    StateNotifierProvider<ProductFormController, AsyncValue<void>>(
        (ref) => ProductFormController(ref));
