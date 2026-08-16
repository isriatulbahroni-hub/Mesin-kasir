import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../providers/cart_provider.dart';
import '../providers/held_cart_provider.dart';

class HeldCartsSheet extends ConsumerWidget {
  const HeldCartsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldAsync = ref.watch(heldCartsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaksi Tertahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Flexible(
              child: heldAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Gagal memuat: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Belum ada transaksi yang ditahan.', style: TextStyle(color: AppColors.charcoal500))),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final h = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(h.label?.isNotEmpty == true ? h.label! : 'Transaksi ditahan'),
                        subtitle: Text('${h.itemCount} item · ${Formatters.rupiah(h.total)} · ${_timeAgo(h.createdAt)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          tooltip: 'Buang',
                          onPressed: () => _discard(context, ref, h.id),
                        ),
                        onTap: () => _resume(context, ref, h.id),
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

  Future<void> _resume(BuildContext context, WidgetRef ref, String id) async {
    final currentCart = ref.read(cartProvider);
    if (currentCart.lines.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Keranjang belum kosong'),
          content: const Text('Melanjutkan transaksi tertahan akan mengganti isi keranjang saat ini. Lanjutkan?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    try {
      final missing = await ref.read(heldCartControllerProvider).resume(id);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk berikut sudah tidak tersedia dan dilewati: ${missing.join(', ')}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal melanjutkan transaksi: $e')));
      }
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang transaksi tertahan?'),
        content: const Text('Transaksi ini akan dihapus permanen dan tidak bisa dilanjutkan lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(heldCartControllerProvider).discard(id);
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
