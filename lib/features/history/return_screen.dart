import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_item.dart';
import 'providers/return_provider.dart';

class ReturnScreen extends ConsumerStatefulWidget {
  final String transactionId;
  final String invoiceNo;
  final List<TransactionItem> items;

  const ReturnScreen({super.key, required this.transactionId, required this.invoiceNo, required this.items});

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  final Map<String, int> _selectedQty = {};
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refundedAsync = ref.watch(refundedQuantitiesProvider(widget.transactionId));

    return Scaffold(
      appBar: AppBar(title: Text('Retur — ${widget.invoiceNo}')),
      body: refundedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (refunded) {
          final returnable = widget.items.where((i) => (refunded[i.id] ?? 0) < i.quantity).toList();
          if (returnable.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Semua item di transaksi ini sudah diretur sepenuhnya.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Pilih item & jumlah yang mau diretur:', style: TextStyle(color: AppColors.charcoal500)),
              const SizedBox(height: 12),
              for (final item in returnable) _ReturnItemTile(
                item: item,
                alreadyRefunded: refunded[item.id] ?? 0,
                selectedQty: _selectedQty[item.id] ?? 0,
                onChanged: (qty) => setState(() {
                  if (qty <= 0) {
                    _selectedQty.remove(item.id);
                  } else {
                    _selectedQty[item.id] = qty;
                  }
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Alasan retur (opsional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_selectedQty.isEmpty || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.warning),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Proses Retur${_selectedQty.isEmpty ? '' : ' (${_selectedQty.values.fold(0, (a, b) => a + b)} item)'}'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final items = _selectedQty.entries.map((e) => {'transaction_item_id': e.key, 'quantity': e.value}).toList();
    final error = await ref.read(returnControllerProvider.notifier).submitReturn(
          transactionId: widget.transactionId,
          items: items,
          reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pop(context, true);
    }
  }
}

class _ReturnItemTile extends StatelessWidget {
  final TransactionItem item;
  final int alreadyRefunded;
  final int selectedQty;
  final ValueChanged<int> onChanged;

  const _ReturnItemTile({
    required this.item,
    required this.alreadyRefunded,
    required this.selectedQty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maxQty = item.quantity - alreadyRefunded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'Dibeli ${item.quantity}${alreadyRefunded > 0 ? ' · sudah diretur $alreadyRefunded' : ''} · ${Formatters.rupiah(item.price)}/pcs',
                    style: const TextStyle(fontSize: 12, color: AppColors.charcoal500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: selectedQty > 0 ? () => onChanged(selectedQty - 1) : null,
            ),
            SizedBox(width: 28, child: Text('$selectedQty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: selectedQty < maxQty ? () => onChanged(selectedQty + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}
