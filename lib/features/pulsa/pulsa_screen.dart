import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/operator_detector.dart';
import '../../models/ppob_product.dart';

// Fitur ini SENGAJA menu terpisah dari POS/Beranda -- alurnya beda: pilih
// kategori, cari nomor/ID tujuan, tunggu respons provider (bisa pending),
// jadi butuh layar sendiri biar gak ganggu kecepatan alur checkout utama.
//
// Saldo yang dipakai di sini PRABAYAR per toko (store_ppob_wallets) --
// toko harus top up dulu (lihat pulsa_topup_screen.dart) sebelum bisa jual.
//
// PENTING (per permintaan pemilik, 24 Agu 2026): "semuanya produk harus
// ada" -- 6 kategori disync dari H2H (bukan cuma pulsa/data/PLN), dan
// masing-masing PUNYA ALUR INPUT SENDIRI sesuai jenis tujuannya, jangan
// dipukul rata pakai 1 dialog "Nomor Tujuan" generik:
//   - Pulsa/Paket Data/Telp&SMS: nomor HP, operator otomatis kedeteksi
//     ("baca kartu"), produk difilter cuma yang cocok operatornya.
//   - E-Wallet: nomor HP juga, TAPI TIDAK difilter by operator (GoPay/
//     OVO/DANA jalan lintas operator SIM, gak ada hubungannya).
//   - Token PLN: ID Pelanggan/No. Meter, ada tombol "Cek Nama Pelanggan"
//     opsional sebelum beli (H2H punya endpoint /pln/check, gratis,
//     gak butuh kredensial H2H).
//   - Voucher Game: User ID (+ Zone ID khusus Mobile Legends), ada
//     tombol "Cek Akun" opsional buat game yang didukung H2H
//     (mobile-legends/free-fire/pubg-mobile).

enum _DestType { phoneWithOperator, phoneNoFilter, meterOrId, gameAccount }

const _categoryConfig = {
  'pulsa': (label: 'Pulsa', destType: _DestType.phoneWithOperator),
  'paket_data': (label: 'Paket Data', destType: _DestType.phoneWithOperator),
  'paket_telp_sms': (label: 'Telp & SMS', destType: _DestType.phoneWithOperator),
  'e_wallet': (label: 'E-Wallet', destType: _DestType.phoneNoFilter),
  'pln': (label: 'Token PLN', destType: _DestType.meterOrId),
  'voucher_game': (label: 'Voucher Game', destType: _DestType.gameAccount),
};

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

// BUG FIX (24 Agu 2026, ditemukan langsung dari testing di HP): sebelumnya
// provider ini fetch SEMUA 8198 produk sekaligus tanpa pagination.
// PostgREST punya limit default 1000 baris per request -- karena diurutkan
// alfabetis per kategori (e_wallet, paket_data, paket_telp_sms, pln,
// pulsa, voucher_game), kategori 'paket_data' SENDIRI (4009 baris) udah
// ngelewatin limit itu, jadi 'pln'/'pulsa'/'voucher_game' (yang alfabetis
// di belakang) TIDAK PERNAH kebaca sama sekali -- makanya tab Pulsa
// selalu kosong walau datanya ada di database.
//
// Fix: family provider per-kategori (cuma fetch yang lagi ditampilkan,
// lebih efisien juga) + loop pagination pakai .range() sampai semua baris
// kebaca, berapa pun jumlahnya -- gak akan pernah ke-cut lagi ke depannya.
final ppobProductsProvider = FutureProvider.autoDispose.family<List<PpobProduct>, String>((ref, category) async {
  final client = ref.watch(supabaseClientProvider);
  const pageSize = 1000;
  final all = <PpobProduct>[];
  var offset = 0;
  while (true) {
    final data = await client
        .from('ppob_products')
        .select()
        .eq('is_active', true)
        .eq('category', category)
        .order('sell_price')
        .range(offset, offset + pageSize - 1);
    final page = (data as List).map((e) => PpobProduct.fromJson(e as Map<String, dynamic>)).toList();
    all.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return all;
});

// Deteksi game dari nama/operator produk, dipakai buat nentuin apakah
// tombol "Cek Akun" bisa ditampilkan (H2H cuma dukung 3 game ini).
String? _detectGameSlug(PpobProduct p) {
  final text = '${p.name} ${p.operatorName ?? ''}'.toLowerCase();
  if (text.contains('mobile legend') || text.contains(' ml ') || text.startsWith('ml')) return 'mobile-legends';
  if (text.contains('free fire') || text.contains('freefire') || text.contains(' ff ')) return 'free-fire';
  if (text.contains('pubg')) return 'pubg-mobile';
  return null;
}

class PulsaScreen extends ConsumerStatefulWidget {
  const PulsaScreen({super.key});
  @override
  ConsumerState<PulsaScreen> createState() => _PulsaScreenState();
}

class _PulsaScreenState extends ConsumerState<PulsaScreen> {
  String _selectedCategory = 'pulsa';
  final _destinationCtrl = TextEditingController();
  final _zoneIdCtrl = TextEditingController();

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _zoneIdCtrl.dispose();
    super.dispose();
  }

  _DestType get _destType => _categoryConfig[_selectedCategory]!.destType;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(currentStaffProvider);
    final walletAsync = ref.watch(ppobWalletBalanceProvider);
    final productsAsync = ref.watch(ppobProductsProvider(_selectedCategory));
    final destType = _destType;
    final detectedOperator = destType == _DestType.phoneWithOperator ? detectOperator(_destinationCtrl.text) : null;

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
          ref.invalidate(ppobProductsProvider(_selectedCategory));
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categoryConfig.entries.map((e) {
                  final selected = _selectedCategory == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value.label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _selectedCategory = e.key;
                        _destinationCtrl.clear();
                        _zoneIdCtrl.clear();
                      }),
                      selectedColor: AppColors.emerald100,
                      labelStyle: TextStyle(color: selected ? AppColors.emerald700 : AppColors.charcoal700),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // ---- Input tujuan: BEDA field & perilaku per tipe kategori ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: destType == _DestType.gameAccount
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _destinationCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'User ID Game', prefixIcon: Icon(Icons.sports_esports_outlined)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _zoneIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Zone ID', hintText: 'khusus ML'),
                          ),
                        ),
                      ],
                    )
                  : TextField(
                      controller: _destinationCtrl,
                      keyboardType: destType == _DestType.meterOrId ? TextInputType.number : TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: destType == _DestType.meterOrId ? 'ID Pelanggan / No. Meter' : 'Nomor HP Pelanggan',
                        hintText: destType == _DestType.meterOrId ? 'mis. 5312xxxxxxxx' : '08xxxxxxxxxx',
                        prefixIcon: Icon(destType == _DestType.meterOrId ? Icons.bolt_outlined : Icons.sim_card_outlined),
                        suffixIcon: destType == _DestType.phoneWithOperator && detectedOperator != null
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
                  if (destType == _DestType.phoneWithOperator) {
                    if (_destinationCtrl.text.trim().length < 4) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Ketik nomor HP pelanggan dulu untuk lihat produk yang sesuai operatornya.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
                        ),
                      );
                    }
                    if (detectedOperator == null) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Operator tidak dikenali dari nomor ini. Periksa lagi nomornya.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
                        ),
                      );
                    }
                  }

                  final filtered = destType == _DestType.phoneWithOperator
                      ? products.where((p) {
                          final opName = (p.operatorName ?? '').toLowerCase();
                          return detectedOperator!.matchKeywords.any((kw) => opName.contains(kw));
                        }).toList()
                      : products;

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

  Future<Map<String, dynamic>?> _tryCheckCustomer(BuildContext context, PpobProduct product) async {
    final client = ref.read(supabaseClientProvider);
    if (_destType == _DestType.meterOrId) {
      final meterId = _destinationCtrl.text.trim();
      if (meterId.length < 6) return null;
      try {
        final res = await client.functions.invoke('h2h-check-customer', body: {'type': 'pln', 'meter_id': meterId});
        final data = res.data;
        if (data is Map && data['ok'] == true) return {'label': 'Nama Pelanggan', 'value': '${data['name']} (${data['power']})'};
      } catch (_) {
        // Cek nama gagal (network/API down) -- non-blocking, tetap boleh lanjut beli.
      }
    } else if (_destType == _DestType.gameAccount) {
      final gameSlug = _detectGameSlug(product);
      final userId = _destinationCtrl.text.trim();
      if (gameSlug == null || userId.length < 3) return null;
      try {
        final res = await client.functions.invoke('h2h-check-customer', body: {
          'type': 'game',
          'game': gameSlug,
          'user_id': userId,
          if (_zoneIdCtrl.text.trim().isNotEmpty) 'zone_id': _zoneIdCtrl.text.trim(),
        });
        final data = res.data;
        if (data is Map && data['ok'] == true) return {'label': 'Nama Akun', 'value': data['username']};
      } catch (_) {
        // sama, non-blocking.
      }
    }
    return null;
  }

  Future<void> _confirmAndOrder(BuildContext context, PpobProduct product) async {
    final isGame = _destType == _DestType.gameAccount;
    final destination = isGame
        ? (_zoneIdCtrl.text.trim().isNotEmpty ? '${_destinationCtrl.text.trim()}|${_zoneIdCtrl.text.trim()}' : _destinationCtrl.text.trim())
        : _destinationCtrl.text.trim();
    final minLength = _destType == _DestType.gameAccount ? 3 : (_destType == _DestType.meterOrId ? 6 : 8);
    if (_destinationCtrl.text.trim().length < minLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tujuan tidak valid')));
      return;
    }
    final staff = await ref.read(currentStaffProvider.future);
    if (staff == null || !context.mounted) return;

    // Cek nama/akun dulu (opsional, non-blocking) buat PLN & game yang didukung.
    Map<String, dynamic>? checkResult;
    if (_destType == _DestType.meterOrId || _destType == _DestType.gameAccount) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(backgroundColor: AppColors.surfaceElevated, content: Row(children: [CircularProgressIndicator(color: AppColors.emerald600), SizedBox(width: 16), Text('Mengecek data...')])),
      );
      checkResult = await _tryCheckCustomer(context, product);
      if (context.mounted) Navigator.pop(context);
    }
    if (!context.mounted) return;

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
            if (checkResult != null) ...[
              const SizedBox(height: 4),
              Text('${checkResult['label']}: ${checkResult['value']}', style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.w600)),
            ] else if (_destType == _DestType.meterOrId || _destType == _DestType.gameAccount) ...[
              const SizedBox(height: 4),
              const Text('Nama tidak bisa diverifikasi -- pastikan tujuan sudah benar.', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
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
