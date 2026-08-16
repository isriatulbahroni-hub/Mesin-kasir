import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';

class DailySales {
  final DateTime date;
  final int revenue;
  final int transactionCount;
  DailySales({required this.date, required this.revenue, required this.transactionCount});
}

class ReportsSummary {
  final List<DailySales> daily; // 7 hari, terurut dari terlama ke terbaru
  final int totalRevenue;
  final int totalTransactions;
  final int totalProfit;

  ReportsSummary({
    required this.daily,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalProfit,
  });
}

final reportsSummaryProvider = FutureProvider.autoDispose<ReportsSummary>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) {
    return ReportsSummary(daily: [], totalRevenue: 0, totalTransactions: 0, totalProfit: 0);
  }

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

  final txRows = await client
      .from('transactions')
      .select('id, total, created_at, status')
      .eq('store_id', staff.storeId)
      .eq('status', 'completed')
      .gte('created_at', startDay.toUtc().toIso8601String());

  final txList = txRows as List;
  final txIds = txList.map((r) => r['id'] as String).toList();

  // Profit = subtotal item (price*qty - diskon item) - cost_price*qty, dijumlah semua item.
  int totalProfit = 0;
  if (txIds.isNotEmpty) {
    final itemRows = await client
        .from('transaction_items')
        .select('price, cost_price, quantity, discount')
        .inFilter('transaction_id', txIds);
    for (final row in (itemRows as List)) {
      final price = (row['price'] as num).toInt();
      final cost = (row['cost_price'] as num).toInt();
      final qty = (row['quantity'] as num).toInt();
      final discount = (row['discount'] as num?)?.toInt() ?? 0;
      totalProfit += (price * qty - discount) - (cost * qty);
    }
  }

  final buckets = <DateTime, DailySales>{};
  for (int i = 0; i < 7; i++) {
    final day = DateTime(startDay.year, startDay.month, startDay.day + i);
    buckets[day] = DailySales(date: day, revenue: 0, transactionCount: 0);
  }

  for (final row in txList) {
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final existing = buckets[dayKey];
    if (existing != null) {
      buckets[dayKey] = DailySales(
        date: dayKey,
        revenue: existing.revenue + (row['total'] as num).toInt(),
        transactionCount: existing.transactionCount + 1,
      );
    }
  }

  final daily = buckets.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  final totalRevenue = daily.fold<int>(0, (sum, d) => sum + d.revenue);
  final totalTransactions = daily.fold<int>(0, (sum, d) => sum + d.transactionCount);

  return ReportsSummary(
    daily: daily,
    totalRevenue: totalRevenue,
    totalTransactions: totalTransactions,
    totalProfit: totalProfit,
  );
});
