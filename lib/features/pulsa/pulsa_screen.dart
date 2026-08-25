import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/ppob_product.dart';

// Fitur ini SENGAJA menu terpisah dari POS/Beranda (bukan dijual sebagai
// "produk" di grid kasir) -- alurnya beda: pilih kategori, cari nomor
// tujuan, tunggu respons provider H2H (bisa pending), jadi butuh layar
// sendiri biar gak ganggu kecepatan alur checkout utama.
//
// Saldo yang dipakai di sini PRABAYAR per toko (store_ppob_wallets) --
// toko harus top up dulu (lihat pulsa_topup_screen.dart) sebelum bisa jual.

final ppobWalletBalanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return 0;
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('store_ppob_wallets')
      .select('balance')
      .eq('store_id', staff.storeId)
      .maybeSingle();
  return (data?['balance'] as num?)?.toInt() ?? 0;
});

// Beda dari staff.role.canManage (owner/admin TOKO) -- ini khusus pemilik
// platform Kasir Pro (lihat tabel platform_admins), yang berhak sync
// katalog produk H2H buat SEMUA toko sekaligus.
final isPlatformAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await client.rpc('is_platform_admin');
    return result == true;
  } catch (_) {
    return false;
  }
});

final ppobProductsProvider = FutureProvider.autoDispose<List<PpobProduct>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('ppob_products')
      .select()
      .eq('is_active', true)
      .order('category')
      .order('sell_price');
  return (data as List).map((e) => PpobProduct.fromJson(e as Map<String, dynamic>)).toList();
});

const _categoryLabels = {
  'pulsa': 'Pulsa',
  'paket_data': 'Paket Data',
  'pln': 'Token PLN',
};

class PulsaScreen extends ConsumerStatefulWidget {
  const PulsaScreen({super.key});
  @override
  ConsumerState<PulsaScreen> createState() => _PulsaScreenState();
}

class _PulsaScreenState extends ConsumerState<PulsaScreen> {
  String _selectedCategory = 'pulsa';

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(currentStaffProvider);
    final walletAsync = ref.watch(ppobWalletBalanceProvider);
    final productsAsync = ref.watch(ppobProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pulsa & Digital'),
        actions: [
          staffAsync.maybeWhen(
            data: (staff) => (staff?.role.canManage ?? false)
                ? IconButton(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    tooltip: 'Top Up Saldo',
                    onPressed: () => context.push('/pulsa/topup'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat',
            onPressed: () => context.push('/pulsa/riwayat'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ppobWalletBalanceProvider);
          ref.invalidate(ppobProductsProvider);
        },
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.emerald600, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo Pulsa Toko', style: TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                        walletAsync.when(
                          data: (bal) => Text(Formatters.rupiah(bal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.charcoal900)),
                          loading: () => const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, _) => const Text('Gagal muat', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categoryLabels.entries.map((e) {
                  final selected = _selectedCategory == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCategory = e.key),
                      selectedColor: AppColors.emerald100,
                      labelStyle: TextStyle(color: selected ? AppColors.emerald700 : AppColors.charcoal700),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
                error: (e, _) => Center(child: Text('Gagal memuat katalog: $e', style: const TextStyle(color: Colors.red))),
                data: (products) {
                  final filtered = products.where((p) => p.category == _selectedCategory).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Belum ada produk di kategori ini.\nHubungi pemilik untuk sync katalog.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w600)),
                          subtitle: p.operatorName != null ? Text(p.operatorName!, style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)) : null,
                          trailing: Text(Formatters.rupiah(p.sellPrice), style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.bold)),
                          onTap: () => _openOrderDialog(context, p),
                        ),
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

  Future<void> _openOrderDialog(BuildContext context, PpobProduct product) async {
    final staff = await ref.read(currentStaffProvider.future);
    if (staff == null || !context.mounted) return;

    final numberCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga jual: ${Formatters.rupiah(product.sellPrice)}', style: const TextStyle(color: AppColors.charcoal700)),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nomor Tujuan', hintText: '08xxxxxxxxxx'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proses')),
        ],
      ),
    );
    if (confirmed != true) return;
    final number = numberCtrl.text.trim();
    if (number.length < 8) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor tujuan tidak valid')));
      return;
    }
    if (!context.mounted) return;
    await _submitOrder(context, staff.id, staff.storeId, product, number);
  }

  Future<void> _submitOrder(BuildContext context, String staffId, String storeId, PpobProduct product, String customerNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        content: Row(children: [CircularProgressIndicator(color: AppColors.emerald600), SizedBox(width: 16), Text('Memproses order...')]),
      ),
    );
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke('h2h-order', body: {
        'store_id': storeId,
        'staff_id': staffId,
        'product_id': product.id,
        'customer_number': customerNumber,
      });
      final data = res.data;
      if (context.mounted) Navigator.pop(context); // tutup loading

      if (data is Map && data['error'] != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${data['error']}'), backgroundColor: Colors.red));
        }
        return;
      }

      final status = data is Map ? data['status'] : null;
      ref.invalidate(ppobWalletBalanceProvider);

      if (!context.mounted) return;
      String msg;
      Color color;
      if (status == 'success') {
        final sn = data['sn'];
        msg = 'Berhasil!${sn != null ? ' SN: $sn' : ''}';
        color = AppColors.emerald600;
      } else if (status == 'pending') {
        msg = 'Order diproses, cek Riwayat beberapa saat lagi.';
        color = Colors.orange;
      } else {
        msg = 'Gagal: ${data is Map ? data['failure_reason'] ?? data['message'] ?? 'tidak diketahui' : 'tidak diketahui'}';
        color = Colors.red;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
