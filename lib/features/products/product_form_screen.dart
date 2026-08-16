import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../pos/providers/pos_provider.dart';
import 'providers/products_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '5');
  String? _categoryId;
  bool _tracksStock = true;
  bool _loaded = false;
  bool _submitting = false;

  bool get isEditing => widget.productId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _hydrate(dynamic product) {
    if (_loaded || product == null) return;
    _loaded = true;
    _nameCtrl.text = product.name;
    _skuCtrl.text = product.sku ?? '';
    _priceCtrl.text = product.sellingPrice.toString();
    _costCtrl.text = product.costPrice.toString();
    _tracksStock = product.stock != null;
    if (product.stock != null) _stockCtrl.text = product.stock.toString();
    _thresholdCtrl.text = product.lowStockThreshold.toString();
    _categoryId = product.categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productAsync = isEditing
        ? ref.watch(productByIdProvider(widget.productId!))
        : const AsyncValue.data(null);

    if (isEditing) {
      productAsync.whenData(_hydrate);
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU (opsional)'),
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
                    for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Jual', prefixText: 'Rp '),
                      validator: (v) => (int.tryParse(v ?? '') == null) ? 'Angka valid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Modal', prefixText: 'Rp '),
                      validator: (v) => (int.tryParse(v ?? '') == null) ? 'Angka valid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lacak stok produk ini'),
                subtitle: const Text('Matikan untuk produk jasa / tanpa stok fisik'),
                value: _tracksStock,
                onChanged: (v) => setState(() => _tracksStock = v),
                activeThumbColor: AppColors.emerald600,
              ),
              if (_tracksStock) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stok'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ambang stok menipis'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Produk'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final error = await ref.read(productFormControllerProvider.notifier).save(
          id: widget.productId,
          name: _nameCtrl.text.trim(),
          sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
          categoryId: _categoryId,
          sellingPrice: int.parse(_priceCtrl.text.trim()),
          costPrice: int.parse(_costCtrl.text.trim()),
          stock: _tracksStock ? (int.tryParse(_stockCtrl.text.trim()) ?? 0) : null,
          lowStockThreshold: int.tryParse(_thresholdCtrl.text.trim()) ?? 5,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pop(context);
    }
  }
}
