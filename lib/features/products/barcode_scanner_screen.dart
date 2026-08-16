import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  /// Jika true, layar TIDAK menutup diri setelah satu kode terbaca —
  /// dipakai di POS agar kasir bisa scan banyak produk berturut-turut.
  /// [onCode] dipanggil setiap kali ada kode baru terbaca.
  final bool continuous;
  final ValueChanged<String>? onCode;

  const BarcodeScannerScreen({super.key, this.continuous = false, this.onCode});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final controller = MobileScannerController();
  bool _cooldown = false;
  String? _lastCode;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_cooldown) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;

    if (!widget.continuous) {
      Navigator.pop(context, code);
      return;
    }

    // Mode kontinu: beri jeda singkat supaya barcode yang sama tidak
    // terbaca berulang kali selagi kamera masih mengarah ke produk itu.
    setState(() { _cooldown = true; _lastCode = code; });
    widget.onCode?.call(code);
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          if (widget.continuous)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 280,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(width: 3, color: _cooldown ? Colors.greenAccent : Colors.white),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              children: [
                if (widget.continuous && _lastCode != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                    child: Text('Terbaca: $_lastCode', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                Text(
                  widget.continuous
                      ? 'Arahkan kamera ke barcode produk berikutnya. Tekan "Selesai" jika sudah.'
                      : 'Arahkan kamera ke barcode. Hasil scan akan menjadi SKU produk.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
