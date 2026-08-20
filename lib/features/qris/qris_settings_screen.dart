import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';

/// QRIS STATIS: 1 gambar QRIS per toko, ditampilkan ke customer saat
/// checkout memilih QRIS. Kasir konfirmasi manual setelah uang masuk.
/// (Bukan QRIS dinamis — itu butuh akun payment gateway seperti
/// Midtrans/Xendit yang generate QR unik + auto-verifikasi per transaksi.)
class QrisSettingsScreen extends ConsumerStatefulWidget {
  const QrisSettingsScreen({super.key});

  @override
  ConsumerState<QrisSettingsScreen> createState() => _QrisSettingsScreenState();
}

class _QrisSettingsScreenState extends ConsumerState<QrisSettingsScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(currentStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QRIS Statis')),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (store) {
          if (store == null) return const Center(child: Text('Toko tidak ditemukan.'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Upload 1 gambar QRIS toko kamu (screenshot dari aplikasi bank/e-wallet). '
                  'Gambar ini akan ditampilkan ke customer saat kasir memilih metode QRIS di checkout.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.charcoal500),
                ),
                const SizedBox(height: 20),
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: store.qrisImageUrl != null
                        ? Image.network(store.qrisImageUrl!, fit: BoxFit.contain)
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.charcoal300),
                                SizedBox(height: 8),
                                Text('Belum ada gambar QRIS', style: TextStyle(color: AppColors.charcoal500)),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : () => _pickAndUpload(store.id),
                  icon: _uploading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded),
                  label: Text(_uploading ? 'Mengunggah...' : 'Upload / Ganti Gambar QRIS'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(String storeId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final ext = picked.path.split('.').last;
      final path = 'qris/$storeId.$ext';

      await client.storage.from('store-assets').upload(
            path,
            File(picked.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = client.storage.from('store-assets').getPublicUrl(path);
      // Tambahkan cache-buster biar Image.network gak nampilin cache lama
      // setelah gambar diganti.
      final urlWithBust = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await client.from('stores').update({'qris_image_url': urlWithBust}).eq('id', storeId);
      ref.invalidate(currentStoreProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gambar QRIS diperbarui.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
