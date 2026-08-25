import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/ppob_order.dart';

final ppobOrdersProvider = FutureProvider.autoDispose<List<PpobOrder>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('ppob_orders')
      .select()
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)
      .limit(100);
  return (data as List).map((e) => PpobOrder.fromJson(e as Map<String, dynamic>)).toList();
});

class PulsaHistoryScreen extends ConsumerWidget {
  const PulsaHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ppobOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Riwayat Pulsa & Digital')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ppobOrdersProvider),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat: $e', style: const TextStyle(color: Colors.red))),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.charcoal500)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = orders[i];
                final (label, color) = switch (o.status) {
                  'success' => ('Berhasil', AppColors.emerald600),
                  'pending' => ('Diproses', Colors.orange),
                  _ => ('Gagal', Colors.red),
                };
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.customerNumber, style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(Formatters.dateTime(o.createdAt), style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                            if (o.sn != null) Text('SN: ${o.sn}', style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                            if (o.failureReason != null) Text(o.failureReason!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formatters.rupiah(o.sellPrice), style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
