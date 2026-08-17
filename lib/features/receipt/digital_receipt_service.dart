import 'package:share_plus/share_plus.dart';

import '../../core/supabase_config.dart';
import '../../core/utils/formatters.dart';

/// Service singleton untuk membentuk & membagikan struk digital (teks),
/// dipakai lintas layar (checkout sheet, detail transaksi) tanpa perlu
/// context Riverpod — pola yang sama dengan PrinterService.
class DigitalReceiptService {
  DigitalReceiptService._();
  static final DigitalReceiptService instance = DigitalReceiptService._();

  /// Ambil data transaksi lengkap dari Supabase, bentuk teks struk, lalu
  /// buka share sheet native (pengguna pilih sendiri: WhatsApp, SMS, Email,
  /// salin teks, dll).
  Future<void> shareReceiptById(String transactionId) async {
    final text = await buildReceiptText(transactionId);
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Struk Belanja'));
  }

  Future<String> buildReceiptText(String transactionId) async {
    final client = SupabaseConfig.client;

    final tx = await client.from('transactions').select().eq('id', transactionId).single();
    final items = await client.from('transaction_items').select().eq('transaction_id', transactionId);
    final payments = await client.from('transaction_payments').select().eq('transaction_id', transactionId);
    final store = await client.from('stores').select().eq('id', tx['store_id']).single();

    return _format(
      storeName: store['name'] as String,
      storeAddress: store['address'] as String?,
      invoiceNo: tx['invoice_no'] as String,
      createdAt: DateTime.parse(tx['created_at'] as String),
      items: (items as List).cast<Map<String, dynamic>>(),
      subtotal: (tx['subtotal'] as num).toInt(),
      discount: (tx['discount'] as num?)?.toInt() ?? 0,
      total: (tx['total'] as num).toInt(),
      paid: (tx['paid_amount'] as num).toInt(),
      change: (tx['change_amount'] as num?)?.toInt() ?? 0,
      paymentMethod: tx['payment_method'] as String,
      payments: (payments as List).cast<Map<String, dynamic>>(),
    );
  }

  String _format({
    required String storeName,
    String? storeAddress,
    required String invoiceNo,
    required DateTime createdAt,
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required int discount,
    required int total,
    required int paid,
    required int change,
    required String paymentMethod,
    required List<Map<String, dynamic>> payments,
  }) {
    final buf = StringBuffer();

    buf.writeln('🧾 *$storeName*');
    if (storeAddress != null && storeAddress.trim().isNotEmpty) buf.writeln(storeAddress);
    buf.writeln('No. Invoice: $invoiceNo');
    buf.writeln('Tanggal: ${Formatters.dateTime(createdAt)}');
    buf.writeln('—' * 24);

    for (final item in items) {
      final name = item['product_name'] as String;
      final qty = (item['quantity'] as num).toInt();
      final price = (item['price'] as num).toInt();
      final lineSubtotal = (item['subtotal'] as num).toInt();
      buf.writeln('$name');
      buf.writeln('$qty x ${Formatters.rupiah(price)} = ${Formatters.rupiah(lineSubtotal)}');
    }
    buf.writeln('—' * 24);

    buf.writeln('Subtotal: ${Formatters.rupiah(subtotal)}');
    if (discount > 0) buf.writeln('Diskon: -${Formatters.rupiah(discount)}');
    buf.writeln('*Total: ${Formatters.rupiah(total)}*');

    if (payments.length > 1) {
      buf.writeln('—' * 24);
      for (final p in payments) {
        final method = (p['method'] as String).toUpperCase();
        final amount = (p['amount'] as num).toInt();
        buf.writeln('Bayar ($method): ${Formatters.rupiah(amount)}');
      }
    } else {
      buf.writeln('Bayar (${paymentMethod.toUpperCase()}): ${Formatters.rupiah(paid)}');
    }
    if (change > 0) buf.writeln('Kembalian: ${Formatters.rupiah(change)}');

    buf.writeln('—' * 24);
    buf.writeln('Terima kasih telah berbelanja 🙏');

    return buf.toString();
  }
}
