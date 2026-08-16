import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_config.dart';
import '../../core/utils/formatters.dart';

/// Service singleton untuk cetak struk ke printer Bluetooth ESC/POS (58mm/80mm).
/// Dipakai lintas layar (checkout sheet, detail transaksi) tanpa perlu
/// context Riverpod, supaya bisa dipanggil dari mana saja dengan mudah.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const _prefKeyMac = 'printer_mac_address';
  static const _prefKeyPaperSize = 'printer_paper_size'; // '58' atau '80'

  Future<String?> getSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyMac);
  }

  Future<void> savePrinter(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMac, macAddress);
  }

  Future<String> getPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyPaperSize) ?? '58';
  }

  Future<void> savePaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPaperSize, size);
  }

  Future<List<BluetoothInfo>> scanPairedDevices() async {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (connected) await PrintBluetoothThermal.disconnect;
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  /// Ambil data transaksi lengkap dari Supabase lalu cetak strukturnya.
  Future<void> printReceiptById(String transactionId) async {
    final client = SupabaseConfig.client;

    final tx = await client.from('transactions').select().eq('id', transactionId).single();
    final items = await client
        .from('transaction_items')
        .select()
        .eq('transaction_id', transactionId);
    final store = await client.from('stores').select().eq('id', tx['store_id']).single();

    await printReceiptRaw(
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
    );
  }

  Future<void> printReceiptRaw({
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
  }) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      throw Exception('Printer belum terhubung. Buka Pengaturan Printer dulu.');
    }

    final paperSize = await getPaperSize();
    final profile = await CapabilityProfile.load();
    final paper = paperSize == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
    if (storeAddress != null && storeAddress.isNotEmpty) {
      bytes.addAll(generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('No: $invoiceNo'));
    bytes.addAll(generator.text(Formatters.dateTime(createdAt)));
    bytes.addAll(generator.hr());

    for (final item in items) {
      final name = item['product_name'] as String;
      final qty = (item['quantity'] as num).toInt();
      final itemSubtotal = (item['subtotal'] as num).toInt();
      bytes.addAll(generator.text(name));
      bytes.addAll(generator.row([
        PosColumn(text: '$qty x', width: 4),
        PosColumn(text: Formatters.rupiah(itemSubtotal), width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(text: Formatters.rupiah(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    if (discount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Diskon', width: 6),
        PosColumn(text: '-${Formatters.rupiah(discount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: Formatters.rupiah(total), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Bayar (${paymentMethod.toUpperCase()})', width: 6),
      PosColumn(text: Formatters.rupiah(paid), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Kembali', width: 6),
      PosColumn(text: Formatters.rupiah(change), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Terima kasih!', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
