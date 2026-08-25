import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/purchase.dart';
import 'providers/inventory_provider.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(purchaseItemsProvider(purchase.id));

    return Scaffold(
      appBar: AppBar(title: Text(purchase.purchaseNo)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Tanggal', Formatters.dateTime(purchase.createdAt)),
                  _row('Status', purchase.status == 'received' ? 'Diterima' : purchase.status),
                  if (purchase.note != null) _row('Catatan', purchase.note!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Item Dibeli', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          itemsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20), child: LinearProgressIndicator()),
            error: (e, _) => Text('Gagal memuat item: $e'),
            data: (items) {
              if (items.isEmpty) return const Text('Tidak ada item.', style: TextStyle(color: AppColors.charcoal500));
              return Column(
                children: [
                  for (final item in items)
                    Card(
                      child: ListTile(
                        title: Text(item.productName ?? '-'),
                        subtitle: Text('${item.quantity} x ${Formatters.rupiah(item.costPrice)}'),
                        trailing: Text(Formatters.rupiah(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    color: AppColors.successBg,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Biaya', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(Formatters.rupiah(purchase.totalCost),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald700, fontSize: 17)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.charcoal500)),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
