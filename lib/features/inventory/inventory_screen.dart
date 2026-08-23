import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'draft_purchase_review_screen.dart';
import 'providers/inventory_provider.dart';
import 'purchase_form_screen.dart';
import 'stock_opname_form_screen.dart';
import 'supplier_form_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final purchasesAsync = ref.watch(purchaseHistoryProvider);
    final draftsAsync = ref.watch(draftPurchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(suppliersProvider);
          ref.invalidate(purchaseHistoryProvider);
          ref.invalidate(draftPurchasesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            draftsAsync.maybeWhen(
              data: (drafts) => drafts.isEmpty
                  ? const SizedBox.shrink()
                  : Card(
                      color: AppColors.warningBg,
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.warning),
                        title: Text('${drafts.length} Draft PO otomatis menunggu review',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: const Text('Dibuat sistem karena stok tembus ambang minimum',
                            style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const DraftPurchaseReviewScreen())),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const PurchaseFormScreen())),
                    icon: const Icon(Icons.inventory_rounded),
                    label: const Text('Terima Barang'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const StockOpnameFormScreen())),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Stock Opname'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Supplier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SupplierFormScreen())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            suppliersAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
              error: (e, _) => Text('Gagal memuat: $e'),
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada supplier.', style: TextStyle(color: AppColors.charcoal500)),
                  );
                }
                return Column(
                  children: [
                    for (final s in suppliers)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(s.name),
                          subtitle: s.phone != null ? Text(s.phone!) : null,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Riwayat Pembelian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            purchasesAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
              error: (e, _) => Text('Gagal memuat: $e'),
              data: (purchases) {
                if (purchases.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada riwayat pembelian.', style: TextStyle(color: AppColors.charcoal500)),
                  );
                }
                return Column(
                  children: [
                    for (final p in purchases)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(p.purchaseNo),
                          subtitle: Text(Formatters.dateTime(p.createdAt)),
                          trailing: Text(Formatters.rupiah(p.totalCost),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
