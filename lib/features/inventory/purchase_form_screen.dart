import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import 'providers/inventory_provider.dart';

class _RestockLine {
  final Product product;
  int quantity;
  int costPrice;
  _RestockLine({required this.product, this.quantity = 1, required this.costPrice});
}

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  String? _supplierId;
  final _noteCtrl = TextEditingController();
  final List<_RestockLine> _lines = [];
  bool _submitting = false;

  int get _totalCost => _lines.fold(0, (sum, l) => sum + l.quantity * l.costPrice);

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Terima Barang (Restock)')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                suppliersAsync.when(
                  data: (suppliers) => DropdownButtonFormField<String>(
                    initialValue: _supplierId,
                    decoration: const InputDecoration(labelText: 'Supplier (opsional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa supplier')),
                      for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    TextButton.icon(
                      onPressed: _pickProduct,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Produk'),
                    ),
                  ],
                ),
                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada produk ditambahkan.', style: TextStyle(color: AppColors.charcoal500)),
                  ),
                for (int i = 0; i < _lines.length; i++) _RestockLineTile(
                  line: _lines[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _lines.removeAt(i)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Biaya', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(Formatters.rupiah(_totalCost),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald700, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (_lines.isEmpty || _submitting) ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Terima Barang & Tambah Stok'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProduct() async {
    final products = await ref.read(inventoryProductListProvider.future);
    if (!mounted) return;
    final available = products.where((p) => !_lines.any((l) => l.product.id == p.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua produk sudah ditambahkan.')));
      return;
    }

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: available.length,
          itemBuilder: (ctx, i) => ListTile(
            title: Text(available[i].name),
            subtitle: Text('Modal saat ini: ${Formatters.rupiah(available[i].costPrice)}'),
            onTap: () => Navigator.pop(ctx, available[i]),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _lines.add(_RestockLine(product: selected, costPrice: selected.costPrice)));
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final items = _lines
        .map((l) => {
              'product_id': l.product.id,
              'quantity': l.quantity,
              'cost_price': l.costPrice,
            })
        .toList();

    final error = await ref.read(inventoryControllerProvider.notifier).receivePurchase(
          supplierId: _supplierId,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          items: items,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang diterima, stok diperbarui.')));
      Navigator.pop(context);
    }
  }
}

class _RestockLineTile extends StatelessWidget {
  final _RestockLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _RestockLineTile({required this.line, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onRemove),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: line.quantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    onChanged: (v) {
                      line.quantity = int.tryParse(v) ?? 1;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: line.costPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Modal', prefixText: 'Rp '),
                    onChanged: (v) {
                      line.costPrice = int.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Subtotal: ${Formatters.rupiah(line.quantity * line.costPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}
