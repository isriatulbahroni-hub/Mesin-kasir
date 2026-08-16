import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../printer/printer_service.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_provider.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.tunai;
  final _paidCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final paid = int.tryParse(_paidCtrl.text.trim()) ?? 0;
    final change = (paid - cart.total).clamp(0, 1 << 62);
    final isCash = _method == PaymentMethod.tunai;
    final canSubmit = isCash ? paid >= cart.total : true;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pembayaran', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Total: ${Formatters.rupiah(cart.total)}',
                style: const TextStyle(color: AppColors.emerald700, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isCash)
              TextField(
                controller: _paidCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Uang diterima',
                  prefixText: 'Rp ',
                ),
              ),
            if (isCash) const SizedBox(height: 10),
            if (isCash)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(Formatters.rupiah(change),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald700)),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (!canSubmit || _submitting) ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _submitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Konfirmasi & Simpan', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final cart = ref.read(cartProvider);
    final paid = _method == PaymentMethod.tunai
        ? (int.tryParse(_paidCtrl.text.trim()) ?? 0)
        : cart.total; // non-tunai dianggap dibayar pas

    final result = await ref.read(checkoutControllerProvider.notifier).checkout(
          method: _method,
          paidAmount: paid,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Transaksi gagal.')),
      );
      return;
    }

    Navigator.pop(context); // tutup sheet pembayaran
    if (result.queued) {
      _showQueuedDialog();
    } else {
      _showSuccessDialog(result.invoiceNo, result.transactionId);
    }
  }

  void _showQueuedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 48),
        title: const Text('Transaksi disimpan offline'),
        content: const Text(
            'Koneksi bermasalah. Transaksi sudah disimpan di perangkat dan akan otomatis '
            'tersinkron begitu koneksi kembali normal.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String? invoiceNo, String? transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.emerald600, size: 48),
        title: const Text('Transaksi berhasil'),
        content: Text(invoiceNo != null ? 'No. Invoice: $invoiceNo' : 'Transaksi berhasil disimpan.'),
        actions: [
          if (transactionId != null)
            TextButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Cetak Struk'),
              onPressed: () async {
                await PrinterService.instance.printReceiptById(transactionId);
              },
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
