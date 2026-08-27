import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/ppob_product.dart';
import 'pulsa_screen.dart';

// Dashboard ini SENGAJA menu & route terpisah total dari halaman toko
// (bukan card yang numpang di /pulsa/topup) -- sesuai permintaan pemilik:
// tidak ada satupun fungsi kepemilikan platform (sync katalog, edit harga,
// approve top-up SEMUA toko) yang boleh nyampur ke dasbor toko biasa.
//
// Setiap aksi mutasi di sini dijaga DUA lapis:
//   1. UI: hanya render kalau isPlatformAdminProvider == true
//   2. Server: RPC/Edge Function-nya sendiri cek is_platform_admin() --
//      jadi walau ada yang coba panggil API langsung (skip UI), tetap
//      ditolak 403/unauthorized.
//
// Layout (kartu statistik, donut chart) diadaptasi dari pola
// github.com/abuanwar072/Flutter-Responsive-Admin-Panel-or-Dashboard
// (referensi dashboard Flutter yang paling banyak dipakai) -- struktur
// info-card & chart, BUKAN kode/logic bisnisnya (itu tetap punya sendiri,
// khusus PPOB/pulsa).

final allPendingDepositsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('store_ppob_deposits')
      .select('*, stores(name), staff(full_name)')
      .eq('status', 'pending')
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

// Dashboard pemilik butuh SEMUA kategori sekaligus (beda dari pulsa_screen.dart
// yang fetch per-kategori) -- pagination penuh, biar gak kena limit default
// PostgREST 1000 baris (bug yang sama seperti ppobProductsProvider sebelum
// diperbaiki, lihat catatan di pulsa_screen.dart).
final allPpobProductsProvider = FutureProvider.autoDispose<List<PpobProduct>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  const pageSize = 1000;
  final all = <PpobProduct>[];
  var offset = 0;
  while (true) {
    final data = await client
        .from('ppob_products')
        .select()
        .order('category')
        .order('sell_price')
        .range(offset, offset + pageSize - 1);
    final page = (data as List).map((e) => PpobProduct.fromJson(e as Map<String, dynamic>)).toList();
    all.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return all;
});

// Statistik ringkas -- agregat di level DB (RPC), BUKAN fetch semua baris
// lalu dijumlah manual di client (itu yang bikin bug limit 1000 baris
// sebelumnya). Satu round-trip buat 5 angka sekaligus.
class PlatformStats {
  final int totalStoreBalance, totalStores, totalActiveProducts, ordersToday, revenueToday;
  PlatformStats({required this.totalStoreBalance, required this.totalStores, required this.totalActiveProducts, required this.ordersToday, required this.revenueToday});
  factory PlatformStats.fromJson(Map<String, dynamic> j) => PlatformStats(
        totalStoreBalance: (j['total_store_balance'] as num?)?.toInt() ?? 0,
        totalStores: (j['total_stores'] as num?)?.toInt() ?? 0,
        totalActiveProducts: (j['total_active_products'] as num?)?.toInt() ?? 0,
        ordersToday: (j['orders_today'] as num?)?.toInt() ?? 0,
        revenueToday: (j['revenue_today'] as num?)?.toInt() ?? 0,
      );
}

final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.rpc('get_platform_stats');
  final row = (res as List).first as Map<String, dynamic>;
  return PlatformStats.fromJson(row);
});

final categoryCountsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.rpc('get_ppob_category_counts');
  return (res as List).cast<Map<String, dynamic>>();
});

const _categoryDisplay = {
  'pulsa': (label: 'Pulsa', color: AppColors.emerald600),
  'paket_data': (label: 'Paket Data', color: Color(0xFF26C6DA)),
  'paket_telp_sms': (label: 'Telp & SMS', color: Color(0xFFFFCA28)),
  'e_wallet': (label: 'E-Wallet', color: Color(0xFFAB47BC)),
  'pln': (label: 'Token PLN', color: Color(0xFFEF5350)),
  'voucher_game': (label: 'Voucher Game', color: Color(0xFF5C6BC0)),
};

class PlatformOwnerDashboardScreen extends ConsumerStatefulWidget {
  const PlatformOwnerDashboardScreen({super.key});
  @override
  ConsumerState<PlatformOwnerDashboardScreen> createState() => _PlatformOwnerDashboardScreenState();
}

class _PlatformOwnerDashboardScreenState extends ConsumerState<PlatformOwnerDashboardScreen> {
  bool _syncing = false;
  final _searchCtrl = TextEditingController();
  String? _categoryFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncCatalog() async {
    setState(() => _syncing = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke('h2h-sync-products', body: {'margin_percent': 5});
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
      final total = data is Map ? data['total_upserted'] : '?';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync selesai: $total produk ter-update.')));
        ref.invalidate(allPpobProductsProvider);
        ref.invalidate(platformStatsProvider);
        ref.invalidate(categoryCountsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _decideDeposit(String depositId, bool approve) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.rpc('decide_ppob_deposit', params: {
        'p_deposit_id': depositId,
        'p_approve': approve,
        'p_notes': null,
      });
      final result = (res as List?)?.firstOrNull?['result'] ?? res;
      if (result == 'unauthorized') throw Exception('Bukan platform admin.');
      if (result == 'already_processed') throw Exception('Sudah diproses sebelumnya.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Top up disetujui.' : 'Top up ditolak.')));
        ref.invalidate(allPendingDepositsProvider);
        ref.invalidate(platformStatsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editPrice(PpobProduct product) async {
    final marginCtrl = TextEditingController(text: product.sellPrice > 0 && product.basePrice > 0 ? (((product.sellPrice - product.basePrice) / product.basePrice) * 100).toStringAsFixed(1) : '5');
    final manualPriceCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga dasar H2H: ${Formatters.rupiah(product.basePrice)}', style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: marginCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Margin (%)')),
            const SizedBox(height: 12),
            TextField(
              controller: manualPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Override Harga Manual (Rp) — opsional', hintText: 'Kosongkan untuk pakai margin di atas'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (confirmed != true) return;

    final margin = double.tryParse(marginCtrl.text.replaceAll(',', '.')) ?? 0;
    final manualPrice = manualPriceCtrl.text.trim().isEmpty ? null : int.tryParse(manualPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.rpc('update_ppob_product_price', params: {
        'p_product_id': product.id,
        'p_margin_percent': margin,
        'p_manual_sell_price': manualPrice,
      });
      final result = (res as List?)?.firstOrNull?['result'] ?? res;
      if (result == 'unauthorized') throw Exception('Bukan platform admin.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harga berhasil diupdate.')));
        ref.invalidate(allPpobProductsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleActive(PpobProduct product) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('toggle_ppob_product_active', params: {'p_product_id': product.id});
      ref.invalidate(allPpobProductsProvider);
      ref.invalidate(platformStatsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlatformAdminAsync = ref.watch(isPlatformAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dashboard Pemilik')),
      body: isPlatformAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat: $e', style: const TextStyle(color: Colors.red))),
        data: (isPlatformAdmin) {
          // Guard server-side juga (RPC/Edge Function) -- ini cuma lapis UI
          // tambahan buat kasus deep-link langsung ke /owner.
          if (!isPlatformAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Akses ditolak. Halaman ini khusus pemilik platform.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal500)),
              ),
            );
          }
          return _buildDashboard(context);
        },
      ),
    );
  }

  Widget _statCard({required IconData icon, required Color color, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: AppColors.charcoal500, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final statsAsync = ref.watch(platformStatsProvider);
    return statsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.emerald600))),
      error: (e, _) => Text('Gagal memuat statistik: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
      data: (s) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _statCard(icon: Icons.account_balance_wallet_rounded, color: AppColors.emerald600, title: 'Total Saldo Semua Toko', value: Formatters.rupiah(s.totalStoreBalance)),
          _statCard(icon: Icons.storefront_rounded, color: const Color(0xFF26C6DA), title: 'Jumlah Toko', value: '${s.totalStores}'),
          _statCard(icon: Icons.receipt_long_rounded, color: const Color(0xFFFFCA28), title: 'Order Hari Ini', value: '${s.ordersToday}'),
          _statCard(icon: Icons.trending_up_rounded, color: const Color(0xFFAB47BC), title: 'Omzet Hari Ini', value: Formatters.rupiah(s.revenueToday)),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    final countsAsync = ref.watch(categoryCountsProvider);
    return countsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.emerald600))),
      error: (e, _) => const SizedBox.shrink(),
      data: (counts) {
        if (counts.isEmpty) return const SizedBox.shrink();
        final total = counts.fold<int>(0, (sum, c) => sum + (c['total'] as num).toInt());
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              SizedBox(
                height: 130,
                width: 130,
                child: Stack(
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: counts.map((c) {
                        final cat = c['category'] as String;
                        final cnt = (c['total'] as num).toInt();
                        final disp = _categoryDisplay[cat];
                        return PieChartSectionData(color: disp?.color ?? AppColors.charcoal500, value: cnt.toDouble(), showTitle: false, radius: 22);
                      }).toList(),
                    )),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$total', style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.bold, fontSize: 18)),
                          const Text('produk', style: TextStyle(color: AppColors.charcoal500, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: counts.map((c) {
                    final cat = c['category'] as String;
                    final cnt = (c['total'] as num).toInt();
                    final disp = _categoryDisplay[cat];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: disp?.color ?? AppColors.charcoal500, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(disp?.label ?? cat, style: const TextStyle(color: AppColors.charcoal700, fontSize: 12))),
                          Text('$cnt', style: const TextStyle(color: AppColors.charcoal900, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final productsAsync = ref.watch(allPpobProductsProvider);
    final depositsAsync = ref.watch(allPendingDepositsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allPpobProductsProvider);
        ref.invalidate(allPendingDepositsProvider);
        ref.invalidate(platformStatsProvider);
        ref.invalidate(categoryCountsProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 16),
                  _buildCategoryChart(),
                  const SizedBox(height: 24),

                  // ---- Sync katalog ----
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.emerald200)),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Katalog Produk H2H', style: TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('Tarik ulang harga & produk terbaru dari H2H.id', style: TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _syncing ? null : _syncCatalog,
                          icon: _syncing
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Sync'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Approval top-up semua toko ----
                  const Text('Permintaan Top Up Menunggu', style: TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  depositsAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.emerald600))),
                    error: (e, _) => Text('Gagal memuat: $e', style: const TextStyle(color: Colors.red)),
                    data: (deposits) {
                      if (deposits.isEmpty) return const Text('Tidak ada permintaan yang menunggu.', style: TextStyle(color: AppColors.charcoal500));
                      return Column(
                        children: deposits.map((d) {
                          final storeName = d['stores']?['name'] ?? '-';
                          final staffName = d['staff']?['full_name'] ?? '-';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(storeName, style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w600)),
                                Text('Diajukan oleh $staffName • ${Formatters.dateTime(DateTime.parse(d['created_at'] as String))}', style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(Formatters.rupiah((d['amount'] as num).toInt()), style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Spacer(),
                                    TextButton(onPressed: () => _decideDeposit(d['id'] as String, false), child: const Text('Tolak', style: TextStyle(color: Colors.red))),
                                    const SizedBox(width: 4),
                                    ElevatedButton(onPressed: () => _decideDeposit(d['id'] as String, true), child: const Text('Setujui')),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---- Kelola harga produk: header + search + filter kategori ----
                  const Text('Kelola Harga Produk', style: TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Cari nama produk...', prefixIcon: Icon(Icons.search_rounded)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Semua'),
                            selected: _categoryFilter == null,
                            onSelected: (_) => setState(() => _categoryFilter = null),
                            selectedColor: AppColors.emerald100,
                          ),
                        ),
                        ..._categoryDisplay.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(e.value.label),
                                selected: _categoryFilter == e.key,
                                onSelected: (_) => setState(() => _categoryFilter = e.key),
                                selectedColor: AppColors.emerald100,
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // ---- List produk: SliverList lazy, JANGAN Column+map biasa --
          // dengan 8198 produk potensial, render eager bikin lag berat.
          productsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.emerald600)))),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('Gagal memuat: $e', style: const TextStyle(color: Colors.red)))),
            data: (products) {
              final query = _searchCtrl.text.trim().toLowerCase();
              final filtered = products.where((p) {
                final matchCategory = _categoryFilter == null || p.category == _categoryFilter;
                final matchQuery = query.isEmpty || p.name.toLowerCase().contains(query) || (p.operatorName ?? '').toLowerCase().contains(query);
                return matchCategory && matchQuery;
              }).toList();

              if (filtered.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Tidak ada produk yang cocok.', style: TextStyle(color: AppColors.charcoal500)))),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: ListTile(
                        title: Text(p.name, style: const TextStyle(color: AppColors.charcoal900)),
                        subtitle: Text('Dasar: ${Formatters.rupiah(p.basePrice)} → Jual: ${Formatters.rupiah(p.sellPrice)}', style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(value: p.isActive, onChanged: (_) => _toggleActive(p), activeColor: AppColors.emerald600),
                            IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _editPrice(p)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
