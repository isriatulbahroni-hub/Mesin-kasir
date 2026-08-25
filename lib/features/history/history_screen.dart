import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';

final historyTransactionsProvider =
    FutureProvider.autoDispose.family<List<Transaction>, DateTime?>((ref, filterDate) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];

  final client = ref.watch(supabaseClientProvider);
  var query = client.from('transactions').select().eq('store_id', staff.storeId);

  if (filterDate != null) {
    final start = DateTime(filterDate.year, filterDate.month, filterDate.day);
    final end = start.add(const Duration(days: 1));
    query = query.gte('created_at', start.toUtc().toIso8601String()).lt('created_at', end.toUtc().toIso8601String());
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  return (data as List).map((e) => Transaction.fromJson(e)).toList();
});

class HistoryScreen extends ConsumerWidget {
  final DateTime? filterDate;
  const HistoryScreen({super.key, this.filterDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(historyTransactionsProvider(filterDate));

    return Scaffold(
      appBar: AppBar(title: Text(filterDate != null ? 'Transaksi ${Formatters.date(filterDate!)}' : 'Riwayat Transaksi')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(historyTransactionsProvider(filterDate)),
        child: txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat: $e')),
          data: (transactions) {
            if (transactions.isEmpty) {
              return const Center(child: Text('Belum ada transaksi.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final tx = transactions[i];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/history/${tx.id}'),
                    title: Text(tx.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${Formatters.dateTime(tx.createdAt)} · ${tx.paymentMethod.label}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.rupiah(tx.total),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        _StatusBadge(status: tx.status),
                      ],
                    ),
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

class _StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case TransactionStatus.completed:
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case TransactionStatus.void_:
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
        break;
      case TransactionStatus.refunded:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
