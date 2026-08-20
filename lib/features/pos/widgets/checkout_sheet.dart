import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../printer/printer_service.dart';
import '../../receipt/digital_receipt_service.dart';
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
              if (_method == PaymentMethod.qris) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _showQrisDialog(context),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('QRIS Statis (konfirmasi manual)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _startDynamicQris(context),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('QRIS Otomatis (Midtrans)'),
                ),
              ],
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

  Future<void> _startDynamicQris(BuildContext context) async {
    final cart = ref.read(cartProvider);
    final staff = ref.read(currentStaffProvider).value;
    final shift = ref.read(activeShiftProvider).value;

    if (staff == null || shift == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sesi staff/shift tidak ditemukan.')));
      return;
    }

    setState(() => _submitting = true);
    Map<String, dynamic> data;
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke('create-qris-payment', body: {
        'staff_id': staff.id,
        'shift_id': shift.id,
        'items': cart.lines
            .map((l) => {
                  'product_id': l.product.id,
                  'product_name': l.product.name,
                  'price': l.product.sellingPrice,
                  'cost_price': l.product.costPrice,
                  'quantity': l.quantity,
                  'discount': l.discount,
                })
            .toList(),
        'transaction_discount': cart.transactionDiscount,
        'note': cart.note.isEmpty ? null : cart.note,
      });

      final resData = res.data;
      if (resData is Map && resData['error'] != null) {
        throw Exception(resData['error']);
      }
      data = Map<String, dynamic>.from(resData as Map);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal membuat QRIS: $e')));
      }
      return;
    }
    if (mounted) setState(() => _submitting = false);
    if (!context.mounted) return;

    final confirmedTxId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DynamicQrisWaitDialog(
        qrisPaymentId: data['qris_payment_id'] as String,
        qrUrl: data['qr_url'] as String,
        amount: data['amount'] as int,
      ),
    );

    if (!context.mounted) return;

    if (confirmedTxId != null) {
      ref.read(cartProvider.notifier).clear();
      Navigator.pop(context); // tutup bottom sheet pembayaran
      _showSuccessDialog(null, confirmedTxId);
    }
  }

  void _showQrisDialog(BuildContext context) {
    final store = ref.read(currentStoreProvider).value;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan QRIS'),
        content: store?.qrisImageUrl != null
            ? SizedBox(
                width: 280,
                height: 280,
                child: Image.network(store!.qrisImageUrl!, fit: BoxFit.contain),
              )
            : const Text(
                'Gambar QRIS belum diatur. Buka Pengaturan → QRIS untuk upload gambar QRIS toko.',
              ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
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
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          if (transactionId != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Cetak Struk',
                  onPressed: () async {
                    try {
                      await PrinterService.instance.printReceiptById(transactionId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Bagikan Struk',
                  onPressed: () async {
                    try {
                      await DigitalReceiptService.instance.shareReceiptById(transactionId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: $e')));
                      }
                    }
                  },
                ),
              ],
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

/// Dialog yang nunggu pembayaran QRIS dinamis (Midtrans) — dengerin realtime
/// perubahan status di tabel qris_payments (dipicu webhook Midtrans begitu
/// customer selesai scan & bayar), auto-close dengan hasil transaction_id
/// begitu status berubah jadi 'paid'.
class _DynamicQrisWaitDialog extends ConsumerStatefulWidget {
  final String qrisPaymentId;
  final String qrUrl;
  final int amount;
  const _DynamicQrisWaitDialog({required this.qrisPaymentId, required this.qrUrl, required this.amount});

  @override
  ConsumerState<_DynamicQrisWaitDialog> createState() => _DynamicQrisWaitDialogState();
}

class _DynamicQrisWaitDialogState extends ConsumerState<_DynamicQrisWaitDialog> {
  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);
    final stream = client
        .from('qris_payments')
        .stream(primaryKey: ['id'])
        .eq('id', widget.qrisPaymentId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final row = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;
        final status = row?['status'] as String? ?? 'pending';

        // Selesai (paid) -> tutup dialog otomatis, kembalikan transaction_id.
        if (status == 'paid' && row?['transaction_id'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(row!['transaction_id'] as String);
            }
          });
        }

        final isFailedOrExpired = status == 'failed' || status == 'expired' || status == 'cancelled';

        return AlertDialog(
          title: const Text('Menunggu Pembayaran QRIS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Formatters.rupiah(widget.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.emerald700)),
              const SizedBox(height: 16),
              if (isFailedOrExpired)
                Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      status == 'expired' ? 'QR sudah kedaluwarsa.' : 'Pembayaran gagal/dibatalkan.',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                )
              else ...[
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Image.network(
                    widget.qrUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald600)),
                    SizedBox(width: 8),
                    Text('Menunggu customer scan & bayar...', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isFailedOrExpired ? 'Tutup' : 'Batalkan'),
            ),
          ],
        );
      },
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
