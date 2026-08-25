import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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

enum _PermissionState { checking, granted, denied, permanentlyDenied }

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final controller = MobileScannerController();
  bool _cooldown = false;
  String? _lastCode;
  _PermissionState _permission = _PermissionState.checking;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    // WAJIB diminta secara runtime (Android 6+/API 23+) - CAMERA itu
    // "dangerous permission", deklarasi di AndroidManifest.xml saja TIDAK
    // CUKUP. Tanpa ini, mobile_scanner gagal start kamera dan cuma nampilin
    // pesan generik "An unexpected error occurred." tanpa penjelasan.
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permission = status.isGranted
          ? _PermissionState.granted
          : status.isPermanentlyDenied
              ? _PermissionState.permanentlyDenied
              : _PermissionState.denied;
    });
  }

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

  Future<void> _retryStartCamera() async {
    // "Coba Lagi" harus beneran minta native camera start ulang, bukan cuma
    // rebuild widget kosong (rebuild doang gak bikin kamera coba nyala lagi
    // kalau controller-nya udah kepalang gagal start sebelumnya).
    try {
      await controller.start();
    } catch (_) {
      // Diamkan - errorBuilder MobileScanner akan tetap nampilin error
      // terbaru kalau masih gagal, gak perlu double-handle di sini.
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode Produk'),
        actions: [
          if (_permission == _PermissionState.granted)
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => controller.toggleTorch(),
            ),
          if (widget.continuous && _permission == _PermissionState.granted)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_permission) {
      case _PermissionState.checking:
        return const Center(child: CircularProgressIndicator());

      case _PermissionState.denied:
        return _PermissionMessage(
          icon: Icons.camera_alt_outlined,
          title: 'Izin kamera dibutuhkan',
          message: 'Aplikasi butuh akses kamera buat scan barcode. Tekan tombol di bawah buat mengizinkan.',
          buttonLabel: 'Izinkan Kamera',
          onPressed: _requestCameraPermission,
        );

      case _PermissionState.permanentlyDenied:
        return _PermissionMessage(
          icon: Icons.settings_outlined,
          title: 'Izin kamera diblokir',
          message: 'Kamu pernah menolak izin kamera secara permanen. Aktifkan manual lewat Pengaturan aplikasi > Izin > Kamera.',
          buttonLabel: 'Buka Pengaturan',
          onPressed: openAppSettings,
        );

      case _PermissionState.granted:
        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              // Signature ini sudah diverifikasi langsung dari source code
              // mobile_scanner v6.0.2 di GitHub (bukan tebakan) - kalau kamera
              // gagal start karena alasan APA PUN, detail errornya sekarang
              // beneran ditampilkan, bukan cuma layar hitam kosong.
              errorBuilder: (context, error, child) => _PermissionMessage(
                icon: Icons.error_outline_rounded,
                title: 'Kamera gagal dibuka',
                message: '${error.errorCode.name}'
                    '${error.errorDetails?.message != null ? '\n${error.errorDetails!.message}' : ''}',
                buttonLabel: 'Coba Lagi',
                onPressed: _retryStartCamera,
              ),
            ),
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
        );
    }
  }
}

class _PermissionMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _PermissionMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
