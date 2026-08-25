import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/operator_detector.dart';
import '../../models/ppob_product.dart';

// Fitur ini SENGAJA menu terpisah dari POS/Beranda (bukan dijual sebagai
// "produk" di grid kasir) -- alurnya beda: pilih kategori, cari nomor
// tujuan, tunggu respons provider (bisa pending), jadi butuh layar
// sendiri biar gak ganggu kecepatan alur checkout utama.
//
// Saldo yang dipakai di sini PRABAYAR per toko (store_ppob_wallets) --
// toko harus top up dulu (lihat pulsa_topup_screen.dart) sebelum bisa jual.
//
// PENTING (per permintaan pemilik, 24 Agu 2026): Pulsa/Paket Data dan
// Token PLN itu DUA ALUR BERBEDA, jangan dipukul rata:
//   - Pulsa/Paket Data: tujuannya nomor HP, dan begitu diketik langsung
//     kedeteksi operatornya (fitur "baca kartu") -- produk yang tampil
//     otomatis difilter cuma yang cocok operatornya, biar kasir gak
//     salah beli (misal beli produk Telkomsel buat nomor XL).
//   - Token PLN: tujuannya ID Pelanggan/No. Meter (BUKAN nomor HP), gak
//     ada konsep "operator" sama sekali, jadi semua produk PLN tampil
//     tanpa filter.

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
// katalog produk & kelola harga buat SEMUA toko sekaligus.
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

// Kategori yang tujuannya nomor HP (butuh deteksi operator). Di luar ini
// (PLN) tujuannya ID pelanggan, bukan nomor HP.
bool _isPhoneBasedCategory(String category) => category == 'pulsa' || category == 'paket_data';

class PulsaScreen extends ConsumerStatefulWidget {
  const PulsaScreen({super.key});
  @override
  ConsumerState<PulsaScreen> createState() => _PulsaScreenState();
}

class _PulsaScreenState extends ConsumerState<PulsaScreen> {
  String _selectedCategory = 'pulsa';
  final _destinationCtrl = TextEditingController();

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(currentStaffProvider);
    final walletAsync = ref.watch(ppobWalletBalanceProvider);
    final productsAsync = ref.watch(ppobProductsProvider);
    final isPhoneBased = _isPhoneBasedCategory(_selectedCategory);
    final detectedOperator = isPhoneBased ? detectOperator(_destinationCtrl.text) : null;

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
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                      onSelected: (_) => setState(() {
                        _selectedCategory = e.key;
                        _destinationCtrl.clear();
                      }),
                      selectedColor: AppColors.emerald100,
                      labelStyle: TextStyle(color: selected ? AppColors.emerald700 : AppColors.charcoal700),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // ---- Input tujuan: beda label & perilaku per kategori ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _destinationCtrl,
                keyboardType: isPhoneBased ? TextInputType.phone : TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: isPhoneBased ? 'Nomor HP Pelanggan' : 'ID Pelanggan / No. Meter',
                  hintText: isPhoneBased ? '08xxxxxxxxxx' : 'mis. 5312xxxxxxxx',
                  prefixIcon: Icon(isPhoneBased ? Icons.sim_card_outlined : Icons.bolt_outlined),
                  suffixIcon: isPhoneBased && detectedOperator != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Chip(
                            label: Text(detectedOperator.label, style: const TextStyle(fontSize: 11, color: AppColors.emerald700)),
                            backgroundColor: AppColors.emerald100,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
                error: (e, _) => Center(child: Text('Gagal memuat katalog: $e', style: const TextStyle(color: Colors.red))),
                data: (products) {
                  final byCategory = products.where((p) => p.category == _selectedCategory).toList();

                  // Kategori nomor-HP: kalau nomor belum cukup panjang buat
                  // dideteksi, JANGAN tampilkan produk campur semua operator
                  // -- ini akar masalah yang bikin bingung sebelumnya.
                  if (isPhoneBased && _destinationCtrl.text.trim().length < 4) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Ketik nomor HP pelanggan dulu untuk lihat produk yang sesuai operatornya.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
                      ),
                    );
                  }
                  if (isPhoneBased && detectedOperator == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Operator tidak dikenali dari nomor ini. Periksa lagi nomornya.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
                      ),
                    );
                  }

                  final filtered = isPhoneBased
                      ? byCategory.where((p) {
                          final opName = (p.operatorName ?? '').toLowerCase();
                          return detectedOperator!.matchKeywords.any((kw) => opName.contains(kw));
                        }).toList()
                      : byCategory;

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada produk untuk ini.\nHubungi pemilik untuk sync katalog.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
                      ),
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
                          onTap: () => _confirmAndOrder(context, p),
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

  Future<void> _confirmAndOrder(BuildContext context, PpobProduct product) async {
    final destination = _destinationCtrl.text.trim();
    final minLength = _isPhoneBasedCategory(_selectedCategory) ? 8 : 6;
    if (destination.length < minLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tujuan tidak valid')));
      return;
    }
    final staff = await ref.read(currentStaffProvider.future);
    if (staff == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tujuan: $destination', style: const TextStyle(color: AppColors.charcoal700)),
            const SizedBox(height: 4),
            Text('Harga jual: ${Formatters.rupiah(product.sellPrice)}', style: const TextStyle(color: AppColors.charcoal700)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proses')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _submitOrder(context, staff.id, staff.storeId, product, destination);
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
