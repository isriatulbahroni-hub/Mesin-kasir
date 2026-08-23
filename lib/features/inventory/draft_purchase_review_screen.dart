import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';
import 'providers/inventory_provider.dart';

/// Draft PO dibuat OTOMATIS oleh sistem (trigger DB) begitu stok produk
/// tembus ambang minimum, khusus produk yang punya "Supplier Default"
/// (diatur di form produk). Di sini admin tinggal review qty/harga, lalu
/// Konfirmasi (stok baru bertambah setelah ini) atau Batalkan.
class DraftPurchaseReviewScreen extends ConsumerWidget {
  const DraftPurchaseReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftPurchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Draft Purchase Order')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(draftPurchasesProvider),
        child: draftsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat: $e')),
          data: (drafts) {
            if (drafts.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.charcoal300),
                  SizedBox(height: 12),
                  Text('Belum ada draft PO otomatis.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      'Draft PO dibuat otomatis kalau ada produk dengan "Supplier Default" '
                      'yang stoknya tembus ambang minimum.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.charcoal300, fontSize: 12),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drafts.length,
              itemBuilder: (context, i) => _DraftPurchaseCard(purchase: drafts[i]),
            );
          },
        ),
      ),
    );
  }
}

class _DraftPurchaseCard extends ConsumerStatefulWidget {
  final Purchase purchase;
  const _DraftPurchaseCard({required this.purchase});

  @override
  ConsumerState<_DraftPurchaseCard> createState() => _DraftPurchaseCardState();
}

class _DraftPurchaseCardState extends ConsumerState<_DraftPurchaseCard> {
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _costCtrls = {};
  bool _submitting = false;

  TextEditingController _qtyCtrl(PurchaseItem item) =>
      _qtyCtrls.putIfAbsent(item.id, () => TextEditingController(text: item.quantity.toString()));
  TextEditingController _costCtrl(PurchaseItem item) =>
      _costCtrls.putIfAbsent(item.id, () => TextEditingController(text: item.costPrice.toString()));

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(purchaseItemsProvider(widget.purchase.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.emerald600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.purchase.purchaseNo,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text(Formatters.dateTime(widget.purchase.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.charcoal500)),
              ],
            ),
            const Divider(height: 20),
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
                            flex: 3,
                            child: Text(item.productName ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _qtyCtrl(item),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _costCtrl(item),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Harga Modal', isDense: true, prefixText: 'Rp '),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : () => _dismiss(context),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          child: const Text('Batalkan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitting ? null : () => _confirm(context, items),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Konfirmasi'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, List<PurchaseItem> items) async {
    setState(() => _submitting = true);
    final payload = items
        .map((item) => {
              'purchase_item_id': item.id,
              'quantity': int.tryParse(_qtyCtrl(item).text.trim()) ?? item.quantity,
              'cost_price': int.tryParse(_costCtrl(item).text.trim()) ?? item.costPrice,
            })
        .toList();

    final error = await ref.read(inventoryControllerProvider.notifier).confirmDraftPurchase(
          purchaseId: widget.purchase.id,
          items: payload,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PO dikonfirmasi, stok diperbarui.')));
    }
  }

  Future<void> _dismiss(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan draft PO ini?'),
        content: const Text('Draft ini tidak akan mempengaruhi stok. Kamu bisa membuatnya lagi manual kapan saja.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    final error = await ref.read(inventoryControllerProvider.notifier).dismissDraftPurchase(widget.purchase.id);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
