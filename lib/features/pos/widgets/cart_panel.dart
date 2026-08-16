import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../providers/cart_provider.dart';
import 'checkout_sheet.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.sand200)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppColors.charcoal900),
                const SizedBox(width: 8),
                Text('Keranjang (${cart.itemCount})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (cart.lines.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    child: const Text('Kosongkan'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.lines.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Keranjang masih kosong.\nKetuk produk untuk menambahkan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.charcoal500)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _CartLineTile(index: i, line: cart.lines[i]),
                  ),
          ),
          if (cart.lines.isNotEmpty) _CartSummary(cart: cart),
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  final int index;
  final CartLine line;
  const _CartLineTile({required this.index, required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(Formatters.rupiah(line.product.sellingPrice),
                        style: const TextStyle(fontSize: 12, color: AppColors.charcoal500)),
                    if (line.discount > 0) ...[
                      const SizedBox(width: 6),
                      Text('- ${Formatters.rupiah(line.discount)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: () => _showLineDiscountDialog(context, ref),
                  child: Text(
                    line.discount > 0 ? 'Ubah diskon' : '+ Diskon item',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.emerald700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          _QtyStepper(
            quantity: line.quantity,
            onDecrement: () => controller.decrementLine(index),
            onIncrement: () => controller.incrementLine(index),
          ),
          const SizedBox(width: 8),
          Text(Formatters.rupiah(line.netSubtotal),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  void _showLineDiscountDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: line.discount > 0 ? line.discount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Diskon untuk ${line.product.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            labelText: 'Nominal diskon (total baris ini)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim()) ?? 0;
              ref.read(cartProvider.notifier).setLineDiscount(index, value.clamp(0, line.grossSubtotal));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyStepper({required this.quantity, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove_rounded, onTap: onDecrement),
        SizedBox(
          width: 28,
          child: Text('$quantity', textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        _StepperButton(icon: Icons.add_rounded, onTap: onIncrement),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.sand100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  final CartState cart;
  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sand50,
        border: Border(top: BorderSide(color: AppColors.sand200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow('Subtotal', Formatters.rupiah(cart.subtotal)),
          GestureDetector(
            onTap: () => _showTransactionDiscountDialog(context, ref),
            child: _SummaryRow(
              'Diskon transaksi',
              cart.transactionDiscount > 0
                  ? '- ${Formatters.rupiah(cart.transactionDiscount)}'
                  : 'Tambah',
              valueColor: cart.transactionDiscount > 0 ? AppColors.danger : AppColors.emerald700,
            ),
          ),
          const Divider(height: 20),
          _SummaryRow('Total', Formatters.rupiah(cart.total), bold: true),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const CheckoutSheet(),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Bayar', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showTransactionDiscountDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: cart.transactionDiscount > 0 ? cart.transactionDiscount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diskon transaksi'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: 'Rp ', labelText: 'Nominal diskon'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim()) ?? 0;
              ref.read(cartProvider.notifier).setTransactionDiscount(value.clamp(0, cart.subtotal));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.charcoal900)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 17 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? (bold ? AppColors.emerald700 : AppColors.charcoal900))),
        ],
      ),
    );
  }
}
