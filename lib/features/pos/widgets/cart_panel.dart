import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/promotion.dart';
import '../../customers/providers/customers_provider.dart';
import '../../promotions/providers/promotions_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/held_cart_provider.dart';
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
                  IconButton(
                    tooltip: 'Tahan transaksi',
                    icon: const Icon(Icons.pause_circle_outline_rounded, size: 22),
                    onPressed: () => _holdCart(context, ref),
                  ),
                if (cart.lines.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    child: const Text('Kosongkan'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _CustomerPicker(cart: cart),
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

  Future<void> _holdCart(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tahan transaksi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama/label (opsional)', hintText: 'mis. Meja 3, Budi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Tahan')),
        ],
      ),
    );
    if (label == null || !context.mounted) return; // dibatalkan
    try {
      await ref.read(heldCartControllerProvider).hold(label: label);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi ditahan. Keranjang dikosongkan.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menahan transaksi: $e')));
      }
    }
  }
}

class _CustomerPicker extends ConsumerWidget {
  final CartState cart;
  const _CustomerPicker({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.customerId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.emerald100, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, size: 18, color: AppColors.emerald700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cart.customerName ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.emerald700), overflow: TextOverflow.ellipsis),
            ),
            InkWell(
              onTap: () => ref.read(cartProvider.notifier).clearCustomer(),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.emerald700),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _pickCustomer(context, ref),
      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
      label: const Text('Pilih Pelanggan (opsional)'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(38)),
    );
  }

  void _pickCustomer(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CustomerPickerSheet(),
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();
  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Pelanggan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(hintText: 'Cari nama/HP...', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: customersAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Gagal memuat: $e')),
                data: (customers) {
                  final filtered = _query.isEmpty
                      ? customers
                      : customers.where((c) => c.name.toLowerCase().contains(_query) || (c.phone?.contains(_query) ?? false)).toList();
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Pelanggan tidak ditemukan.', style: TextStyle(color: AppColors.charcoal500))),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text('${c.phone ?? '-'} · ${c.points} poin'),
                        onTap: () {
                          ref.read(cartProvider.notifier).setCustomer(c.id, c.name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
            onTap: () => _showDiscountOptions(context, ref),
            child: _SummaryRow(
              cart.promotionName != null ? 'Promo: ${cart.promotionName}' : 'Diskon transaksi',
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

  void _showDiscountOptions(BuildContext context, WidgetRef ref) {
    if (cart.promotionName != null) {
      // Sudah ada promo terpasang -> tap langsung tawarkan lepas.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lepas promo ini?'),
          content: Text('${cart.promotionName} akan dilepas dari transaksi ini.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () { ref.read(cartProvider.notifier).clearPromotion(); Navigator.pop(ctx); },
              child: const Text('Lepas'),
            ),
          ],
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Pakai Promo/Voucher'),
            onTap: () { Navigator.pop(context); _showPromotionSheet(context, ref); },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Diskon manual'),
            onTap: () { Navigator.pop(context); _showTransactionDiscountDialog(context, ref); },
          ),
        ]),
      ),
    );
  }

  void _showPromotionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PromotionSheet(subtotal: cart.subtotal),
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

class _PromotionSheet extends ConsumerStatefulWidget {
  final int subtotal;
  const _PromotionSheet({required this.subtotal});

  @override
  ConsumerState<_PromotionSheet> createState() => _PromotionSheetState();
}

class _PromotionSheetState extends ConsumerState<_PromotionSheet> {
  final _codeCtrl = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyByCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _checking = true; _error = null; });
    try {
      final promo = await ref.read(promotionControllerProvider).findByCode(code);
      final discount = promo.computeDiscount(widget.subtotal);
      if (discount <= 0) {
        setState(() => _error = 'Belum memenuhi syarat minimal belanja Rp ${promo.minimumPurchase}.');
        return;
      }
      ref.read(cartProvider.notifier).applyPromotion(id: promo.id, name: promo.name, discountAmount: discount);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst(RegExp(r'^.*?Exception: '), ''));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _applyPromo(Promotion promo) {
    final discount = promo.computeDiscount(widget.subtotal);
    if (discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Belum memenuhi syarat minimal belanja ${Formatters.rupiah(promo.minimumPurchase)}.')),
      );
      return;
    }
    ref.read(cartProvider.notifier).applyPromotion(id: promo.id, name: promo.name, discountAmount: discount);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final promosAsync = ref.watch(activePromotionsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pakai Promo/Voucher', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Masukkan kode voucher'),
                    onSubmitted: (_) => _applyByCode(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _checking ? null : _applyByCode,
                  child: _checking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pakai'),
                ),
              ],
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
            const Divider(height: 28),
            const Text('Atau pilih promo yang sedang berlaku:', style: TextStyle(color: AppColors.charcoal500, fontSize: 12)),
            const SizedBox(height: 8),
            Flexible(
              child: promosAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Gagal memuat: $e')),
                data: (promos) {
                  final visible = promos.where((p) => p.code == null).toList(); // kode voucher lewat kolom di atas
                  if (visible.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada promo yang sedang berlaku.', style: TextStyle(color: AppColors.charcoal500)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final p = visible[i];
                      final label = p.promotionType == 'percentage' ? '${p.value}%' : Formatters.rupiah(p.value);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_offer_outlined, color: AppColors.emerald700),
                        title: Text(p.name),
                        subtitle: p.minimumPurchase > 0 ? Text('Min. belanja ${Formatters.rupiah(p.minimumPurchase)}') : null,
                        trailing: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald700)),
                        onTap: () => _applyPromo(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
