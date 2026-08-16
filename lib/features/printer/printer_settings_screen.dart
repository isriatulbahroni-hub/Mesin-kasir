import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/theme/app_colors.dart';
import 'printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothInfo> _devices = [];
  String? _savedMac;
  String _paperSize = '58';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    final devices = await PrinterService.instance.scanPairedDevices();
    final savedMac = await PrinterService.instance.getSavedPrinterMac();
    final paperSize = await PrinterService.instance.getPaperSize();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _savedMac = savedMac;
      _paperSize = paperSize;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _init),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald600))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Ukuran Kertas', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('58mm'),
                        selected: _paperSize == '58',
                        onSelected: (_) async {
                          await PrinterService.instance.savePaperSize('58');
                          setState(() => _paperSize = '58');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('80mm'),
                        selected: _paperSize == '80',
                        onSelected: (_) async {
                          await PrinterService.instance.savePaperSize('80');
                          setState(() => _paperSize = '80');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Printer Terpasang (Paired)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Pastikan printer sudah dipasangkan (pair) lewat pengaturan Bluetooth HP dulu, baru pilih di sini.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.charcoal500),
                ),
                const SizedBox(height: 12),
                if (_devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Belum ada printer yang di-pair.'),
                  )
                else
                  ..._devices.map((d) => Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.print_rounded,
                            color: _savedMac == d.macAdress ? AppColors.emerald600 : AppColors.charcoal300,
                          ),
                          title: Text(d.name),
                          subtitle: Text(d.macAdress),
                          trailing: _savedMac == d.macAdress
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald600)
                              : null,
                          onTap: () => _connectAndSave(d),
                        ),
                      )),
                const SizedBox(height: 24),
                if (_savedMac != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Tes Cetak Struk'),
                    onPressed: _testPrint,
                  ),
              ],
            ),
    );
  }

  Future<void> _connectAndSave(BluetoothInfo device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
    );
    final success = await PrinterService.instance.connect(device.macAdress);
    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      await PrinterService.instance.savePrinter(device.macAdress);
      setState(() => _savedMac = device.macAdress);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Terhubung ke ${device.name}')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal terhubung ke printer.')));
    }
  }

  Future<void> _testPrint() async {
    try {
      await PrinterService.instance.printReceiptRaw(
        storeName: 'Kasir Pro',
        storeAddress: 'Tes Cetak Struk',
        invoiceNo: 'TEST-0001',
        createdAt: DateTime.now(),
        items: [
          {'product_name': 'Contoh Produk', 'quantity': 1, 'subtotal': 10000},
        ],
        subtotal: 10000,
        discount: 0,
        total: 10000,
        paid: 10000,
        change: 0,
        paymentMethod: 'tunai',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
    }
  }
}
