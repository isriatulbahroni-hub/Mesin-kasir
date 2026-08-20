import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_item.dart';
import 'providers/kitchen_provider.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Display')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.charcoal300),
                  SizedBox(height: 8),
                  Text('Semua pesanan sudah selesai 🎉', style: TextStyle(color: AppColors.charcoal500)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 1.6 : 0.85,
            ),
            itemCount: orders.length,
            itemBuilder: (context, i) => _OrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final KitchenOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.transaction.invoiceNo,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Text(Formatters.time(order.transaction.createdAt),
                    style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                children: [for (final item in order.items) _KitchenItemTile(item: item)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenItemTile extends ConsumerWidget {
  final TransactionItem item;
  const _KitchenItemTile({required this.item});

  static const _statusFlow = ['pending', 'preparing', 'ready', 'served'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIdx = _statusFlow.indexOf(item.kitchenStatus);
    final nextStatus = currentIdx < _statusFlow.length - 1 ? _statusFlow[currentIdx + 1] : null;
    final (bg, fg, label) = switch (item.kitchenStatus) {
      'pending' => (AppColors.warningBg, AppColors.warning, 'Menunggu'),
      'preparing' => (AppColors.infoBg, AppColors.info, 'Diproses'),
      'ready' => (AppColors.successBg, AppColors.success, 'Siap'),
      _ => (AppColors.sand200, AppColors.charcoal500, 'Selesai'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('${item.quantity}x ${item.productName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w700)),
          ),
          if (nextStatus != null)
            InkWell(
              onTap: () => ref.read(kitchenControllerProvider).updateStatus(item.id, nextStatus),
              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.emerald600),
            ),
        ],
      ),
    );
  }
}
