import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../pos/providers/pos_provider.dart';
import 'providers/products_provider.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/products/new'),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('Belum ada produk. Tambahkan lewat tombol +'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ProductTile(product: products[i]),
          );
        },
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/products/edit/${product.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: product.photoUrl != null
              ? Image.network(product.photoUrl!, fit: BoxFit.cover)
              : const Icon(Icons.inventory_2_outlined, color: AppColors.charcoal300),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${Formatters.rupiah(product.sellingPrice)} · ${product.tracksStock ? "Stok ${product.stock}" : "Non-stok"}',
          style: TextStyle(
            color: product.isLowStock ? AppColors.warning : AppColors.charcoal500,
            fontSize: 12.5,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              context.push('/products/edit/${product.id}');
            } else if (v == 'deactivate') {
              await ref.read(productFormControllerProvider.notifier).setActive(product.id, false);
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'deactivate', child: Text('Nonaktifkan')),
          ],
        ),
      ),
    );
  }
}
