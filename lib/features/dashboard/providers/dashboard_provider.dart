import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/product.dart';

class DashboardSummary {
  final int todayRevenue;
  final int todayTransactionCount;
  final int todayItemsSold;
  final List<Product> lowStockProducts;

  DashboardSummary({
    required this.todayRevenue,
    required this.todayTransactionCount,
    required this.todayItemsSold,
    required this.lowStockProducts,
  });
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) {
    return DashboardSummary(
        todayRevenue: 0, todayTransactionCount: 0, todayItemsSold: 0, lowStockProducts: []);
  }

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

  final txRows = await client
      .from('transactions')
      .select('id, total, status')
      .eq('store_id', staff.storeId)
      .eq('status', 'completed')
      .gte('created_at', startOfDay.toIso8601String());

  final txList = txRows as List;
  final revenue = txList.fold<int>(0, (sum, r) => sum + ((r['total'] as num).toInt()));
  final txIds = txList.map((r) => r['id'] as String).toList();

  int itemsSold = 0;
  if (txIds.isNotEmpty) {
    final itemRows = await client
        .from('transaction_items')
        .select('quantity, transaction_id')
        .inFilter('transaction_id', txIds);
    itemsSold = (itemRows as List).fold<int>(0, (sum, r) => sum + ((r['quantity'] as num).toInt()));
  }

  final productRows = await client
      .from('products')
      .select()
      .eq('store_id', staff.storeId)
      .eq('is_active', true)
      .not('stock', 'is', null);

  final lowStock = (productRows as List)
      .map(Product.fromJson)
      .where((p) => p.isLowStock)
      .toList();

  return DashboardSummary(
    todayRevenue: revenue,
    todayTransactionCount: txList.length,
    todayItemsSold: itemsSold,
    lowStockProducts: lowStock,
  );
});
