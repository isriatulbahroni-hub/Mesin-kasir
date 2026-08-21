import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat dashboard: $e')),
          data: (summary) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.payments_rounded,
                      label: 'Omzet Hari Ini',
                      value: Formatters.rupiah(summary.todayRevenue),
                      color: AppColors.emerald600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Transaksi',
                      value: '${summary.todayTransactionCount}',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.shopping_bag_rounded,
                label: 'Item Terjual Hari Ini',
                value: '${summary.todayItemsSold} item',
                color: AppColors.charcoal700,
                fullWidth: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 6),
                  Text('Stok Menipis (${summary.lowStockProducts.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              if (summary.lowStockProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Semua stok aman.', style: TextStyle(color: AppColors.charcoal500)),
                )
              else
                ...summary.lowStockProducts.map((p) => Card(
                      child: ListTile(
                        onTap: () => context.push('/products/edit/${p.id}'),
                        leading: const Icon(Icons.inventory_2_outlined, color: AppColors.warning),
                        title: Text(p.name),
                        trailing: Text('${p.stock} tersisa',
                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.charcoal500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontSize: fullWidth ? 20 : 17, fontWeight: FontWeight.w800, color: AppColors.charcoal900)),
          ],
        ),
      ),
    );
  }
}
