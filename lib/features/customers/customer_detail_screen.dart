import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'providers/customers_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    final ledgerAsync = ref.watch(customerPointLedgerProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/customers/edit/$customerId'),
          ),
        ],
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (customer) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            if (customer.phone != null) Text(customer.phone!, style: const TextStyle(color: AppColors.charcoal500)),
            if (customer.email != null) Text(customer.email!, style: const TextStyle(color: AppColors.charcoal500)),
            if (customer.memberCode != null) Text('Kode: ${customer.memberCode}', style: const TextStyle(color: AppColors.charcoal500)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.emerald100, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo Poin', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.emerald700)),
                  Text('${customer.points}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.emerald700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Riwayat Poin', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ledgerAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat: $e'),
              data: (ledger) {
                if (ledger.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada riwayat poin.', style: TextStyle(color: AppColors.charcoal500)),
                  );
                }
                return Column(
                  children: [
                    for (final l in ledger)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['reason'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(Formatters.dateTime(DateTime.parse(l['created_at'] as String)),
                                      style: const TextStyle(fontSize: 12, color: AppColors.charcoal500)),
                                ],
                              ),
                            ),
                            Text(
                              '${(l['points_delta'] as num) > 0 ? '+' : ''}${l['points_delta']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: (l['points_delta'] as num) > 0 ? AppColors.emerald700 : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Nonaktifkan pelanggan ini?'),
                    content: const Text('Pelanggan tidak akan muncul lagi di daftar/pemilihan POS.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nonaktifkan')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(customerControllerProvider).deactivate(customerId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Nonaktifkan Pelanggan'),
            ),
          ],
        ),
      ),
    );
  }
}
