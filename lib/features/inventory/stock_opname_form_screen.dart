import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import 'providers/inventory_provider.dart';

class StockOpnameFormScreen extends ConsumerStatefulWidget {
  const StockOpnameFormScreen({super.key});

  @override
  ConsumerState<StockOpnameFormScreen> createState() => _StockOpnameFormScreenState();
}

class _StockOpnameFormScreenState extends ConsumerState<StockOpnameFormScreen> {
  final _noteCtrl = TextEditingController();
  final Map<String, int> _counted = {}; // productId -> counted_stock
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(inventoryProductListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Opname')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hitung stok fisik semua produk yang ingin dicek, masukkan angkanya. '
                  'Produk yang tidak diisi tidak akan berubah stoknya.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.charcoal500),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (products) {
                final tracked = products.where((p) => p.tracksStock).toList();
                if (tracked.isEmpty) {
                  return const Center(child: Text('Tidak ada produk yang melacak stok.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tracked.length,
                  itemBuilder: (context, i) => _OpnameLineTile(
                    product: tracked[i],
                    onChanged: (v) {
                      if (v == null) {
                        _counted.remove(tracked[i].id);
                      } else {
                        _counted[tracked[i].id] = v;
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Terapkan Penyesuaian Stok'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_counted.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Isi minimal 1 hasil hitung fisik.')));
      return;
    }

    setState(() => _submitting = true);
    final items = _counted.entries
        .map((e) => {'product_id': e.key, 'counted_stock': e.value})
        .toList();

    final error = await ref.read(inventoryControllerProvider.notifier).applyStockOpname(
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          items: items,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok berhasil disesuaikan.')));
      Navigator.pop(context);
    }
  }
}

class _OpnameLineTile extends StatelessWidget {
  final Product product;
  final ValueChanged<int?> onChanged;
  const _OpnameLineTile({required this.product, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text('Stok sistem: ${product.stock}'),
        trailing: SizedBox(
          width: 90,
          child: TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'Fisik', isDense: true),
            onChanged: (v) => onChanged(int.tryParse(v)),
          ),
        ),
      ),
    );
  }
}
