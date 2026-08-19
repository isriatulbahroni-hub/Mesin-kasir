import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/promotion.dart';
import 'providers/promotions_provider.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(allPromotionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo & Voucher'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => context.push('/promotions/new'))],
      ),
      body: promosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (promos) {
          if (promos.isEmpty) {
            return const Center(child: Text('Belum ada promo. Tambahkan lewat tombol +'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PromotionTile(promo: promos[i]),
          );
        },
      ),
    );
  }
}

class _PromotionTile extends ConsumerWidget {
  final Promotion promo;
  const _PromotionTile({required this.promo});

  static const _typeLabels = {
    'percentage': 'Persen', 'fixed': 'Nominal', 'voucher': 'Voucher',
    'buy_x_get_y': 'Beli X Gratis Y (belum didukung)', 'bundle': 'Bundle (belum didukung)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final expired = now.isAfter(promo.endsAt);
    final valueLabel = promo.promotionType == 'percentage' ? '${promo.value}%' : Formatters.rupiah(promo.value);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(promo.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_typeLabels[promo.promotionType] ?? promo.promotionType} · $valueLabel'
                '${promo.code != null ? ' · Kode: ${promo.code}' : ''}'),
            Text(
              '${Formatters.date(promo.startsAt)} – ${Formatters.date(promo.endsAt)}'
              '${promo.usageLimit != null ? ' · ${promo.usedCount}/${promo.usageLimit} dipakai' : ''}'
              '${expired ? ' · KEDALUWARSA' : ''}',
              style: TextStyle(fontSize: 12, color: expired ? AppColors.danger : AppColors.charcoal500),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Switch(
          value: promo.isActive,
          activeThumbColor: AppColors.emerald600,
          onChanged: (v) => ref.read(promotionControllerProvider).setActive(promo.id, v),
        ),
      ),
    );
  }
}
