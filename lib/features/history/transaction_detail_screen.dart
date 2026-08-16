import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../models/transaction_item.dart';
import '../printer/printer_service.dart';
import 'providers/transaction_action_provider.dart';

final _transactionDetailProvider =
    FutureProvider.autoDispose.family<Transaction, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('transactions').select().eq('id', id).single();
  return Transaction.fromJson(data);
});

final _transactionItemsProvider =
    FutureProvider.autoDispose.family<List<TransactionItem>, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('transaction_items').select().eq('transaction_id', id);
  return (data as List).map((e) => TransactionItem.fromJson(e)).toList();
});

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionDetailProvider(transactionId));
    final itemsAsync = ref.watch(_transactionItemsProvider(transactionId));
    final staffAsync = ref.watch(currentStaffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => PrinterService.instance.printReceiptById(transactionId),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (tx) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(tx.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(Formatters.dateTime(tx.createdAt), style: const TextStyle(color: AppColors.charcoal500)),
            const SizedBox(height: 16),
            itemsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat item: $e'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${item.productName} x${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text(Formatters.rupiah(item.subtotal)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
            _Row('Subtotal', Formatters.rupiah(tx.subtotal)),
            if (tx.discount > 0) _Row('Diskon', '- ${Formatters.rupiah(tx.discount)}'),
            _Row('Total', Formatters.rupiah(tx.total), bold: true),
            _Row('Dibayar', Formatters.rupiah(tx.paidAmount)),
            _Row('Kembalian', Formatters.rupiah(tx.changeAmount)),
            _Row('Metode', tx.paymentMethod.label),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tx.status == TransactionStatus.completed
                    ? AppColors.successBg
                    : tx.status == TransactionStatus.void_
                        ? AppColors.dangerBg
                        : AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Status: ${tx.status.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
            staffAsync.maybeWhen(
              data: (staff) {
                final canManage = staff?.role.canManage ?? false;
                if (!canManage || tx.status != TransactionStatus.completed) {
                  return const SizedBox.shrink();
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmAction(context, ref, tx, 'void'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Text('Void Transaksi'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmAction(context, ref, tx, 'refunded'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                        child: const Text('Refund'),
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, WidgetRef ref, Transaction tx, String newStatus) {
    final reasonCtrl = TextEditingController();
    final label = newStatus == 'void' ? 'Void' : 'Refund';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Transaksi ${tx.invoiceNo}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok produk akan dikembalikan otomatis. Tindakan ini tidak bisa dibatalkan.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'void' ? AppColors.danger : AppColors.warning,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await ref.read(transactionActionControllerProvider.notifier).voidOrRefund(
                    transactionId: tx.id,
                    newStatus: newStatus,
                    reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  );
              if (!context.mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              } else {
                ref.invalidate(_transactionDetailProvider(tx.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Transaksi berhasil di-$label.')),
                );
              }
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? AppColors.emerald700 : AppColors.charcoal900)),
        ],
      ),
    );
  }
}
