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
  bool _splitMode = false;
  final List<_SplitEntry> _splitEntries = [];

  @override
  void dispose() {
    _paidCtrl.dispose();
    for (final e in _splitEntries) { e.amountCtrl.dispose(); }
    super.dispose();
  }

  int get _splitTotal => _splitEntries.fold(0, (sum, e) => sum + (int.tryParse(e.amountCtrl.text.trim()) ?? 0));

  void _addSplitEntry([int? amount]) {
    setState(() => _splitEntries.add(_SplitEntry(
          method: PaymentMethod.tunai,
          amountCtrl: TextEditingController(text: amount != null && amount > 0 ? amount.toString() : ''),
        )));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final paid = int.tryParse(_paidCtrl.text.trim()) ?? 0;
    final change = (paid - cart.total).clamp(0, 1 << 62);
    final isCash = _method == PaymentMethod.tunai;
    final splitRemaining = cart.total - _splitTotal;
    final canSubmit = _splitMode
        ? (_splitEntries.isNotEmpty && _splitTotal >= cart.total && _splitEntries.every((e) => (int.tryParse(e.amountCtrl.text.trim()) ?? 0) > 0))
        : (isCash ? paid >= cart.total : true);

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
            Row(
              children: [
                Expanded(
                  child: Text('Pembayaran', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _splitMode = !_splitMode;
                    if (_splitMode && _splitEntries.isEmpty) _addSplitEntry(cart.total);
                  }),
                  icon: Icon(_splitMode ? Icons.close_rounded : Icons.call_split_rounded, size: 18),
                  label: Text(_splitMode ? 'Satu metode' : 'Split bayar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Total: ${Formatters.rupiah(cart.total)}',
                style: const TextStyle(color: AppColors.emerald700, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 16),
            if (!_splitMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in PaymentMethod.values.where((m) => m != PaymentMethod.campuran))
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
            ] else ...[
              for (int i = 0; i < _splitEntries.length; i++) _SplitEntryRow(
                entry: _splitEntries[i],
                onChanged: () => setState(() {}),
                onRemove: _splitEntries.length > 1 ? () => setState(() => _splitEntries.removeAt(i)) : null,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _addSplitEntry(splitRemaining > 0 ? splitRemaining : null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah metode pembayaran'),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(splitRemaining > 0 ? 'Sisa yang harus dibayar' : 'Kembalian', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    Formatters.rupiah(splitRemaining > 0 ? splitRemaining : -splitRemaining),
                    style: TextStyle(fontWeight: FontWeight.w700, color: splitRemaining > 0 ? AppColors.danger : AppColors.emerald700),
                  ),
                ],
              ),
            ],
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

    final CheckoutResult result;
    if (_splitMode) {
      final splitPayments = _splitEntries
          .map((e) => {'method': e.method.name, 'amount': int.tryParse(e.amountCtrl.text.trim()) ?? 0})
          .where((p) => (p['amount'] as int) > 0)
          .toList();
      result = await ref.read(checkoutControllerProvider.notifier).checkout(
            method: PaymentMethod.campuran,
            paidAmount: _splitTotal,
            splitPayments: splitPayments,
          );
    } else {
      final paid = _method == PaymentMethod.tunai
          ? (int.tryParse(_paidCtrl.text.trim()) ?? 0)
          : cart.total; // non-tunai dianggap dibayar pas
      result = await ref.read(checkoutControllerProvider.notifier).checkout(
            method: _method,
            paidAmount: paid,
          );
    }

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

class _SplitEntry {
  PaymentMethod method;
  final TextEditingController amountCtrl;
  _SplitEntry({required this.method, required this.amountCtrl});
}

class _SplitEntryRow extends StatefulWidget {
  final _SplitEntry entry;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _SplitEntryRow({required this.entry, required this.onChanged, this.onRemove});

  @override
  State<_SplitEntryRow> createState() => _SplitEntryRowState();
}

class _SplitEntryRowState extends State<_SplitEntryRow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<PaymentMethod>(
              value: widget.entry.method,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: [
                for (final m in PaymentMethod.values.where((m) => m != PaymentMethod.campuran))
                  DropdownMenuItem(value: m, child: Text(m.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (m) { if (m != null) setState(() => widget.entry.method = m); },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: widget.entry.amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => widget.onChanged(),
              decoration: const InputDecoration(isDense: true, prefixText: 'Rp ', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            ),
          ),
          if (widget.onRemove != null)
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger), onPressed: widget.onRemove),
        ],
      ),
    );
  }
}
