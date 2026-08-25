import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'pulsa_screen.dart';

final ppobDepositsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('store_ppob_deposits')
      .select()
      .eq('store_id', staff.storeId)
      .order('created_at', ascending: false)
      .limit(30);
  return (data as List).cast<Map<String, dynamic>>();
});

class PulsaTopupScreen extends ConsumerStatefulWidget {
  const PulsaTopupScreen({super.key});
  @override
  ConsumerState<PulsaTopupScreen> createState() => _PulsaTopupScreenState();
}

class _PulsaTopupScreenState extends ConsumerState<PulsaTopupScreen> {
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  bool _syncing = false;

  Future<void> _syncCatalog() async {
    setState(() => _syncing = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke('h2h-sync-products', body: {'margin_percent': 5});
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      final total = data is Map ? data['total_upserted'] : '?';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync selesai: $total produk ter-update.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak valid')));
      return;
    }
    final staff = await ref.read(currentStaffProvider.future);
    if (staff == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('store_ppob_deposits').insert({
        'store_id': staff.storeId,
        'requested_by': staff.id,
        'amount': amount,
      });
      if (mounted) {
        _amountCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan top up terkirim, menunggu persetujuan.')));
        ref.invalidate(ppobDepositsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(ppobWalletBalanceProvider);
    final depositsAsync = ref.watch(ppobDepositsProvider);
    final isPlatformAdminAsync = ref.watch(isPlatformAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Top Up Saldo Pulsa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          isPlatformAdminAsync.maybeWhen(
            data: (isPlatformAdmin) => !isPlatformAdmin
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                              Text('Tarik ulang harga & produk terbaru dari H2H.id (margin 5%)', style: TextStyle(color: AppColors.charcoal500, fontSize: 12)),
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
            orElse: () => const SizedBox.shrink(),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo Saat Ini', style: TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                walletAsync.when(
                  data: (bal) => Text(Formatters.rupiah(bal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal900)),
                  loading: () => const SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => const Text('Gagal muat', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ajukan Top Up', style: TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          const Text(
            'Kirim jumlah top up yang diinginkan. Setelah transfer dana ke pemilik platform, permintaan akan diverifikasi dan saldo otomatis ditambahkan.',
            style: TextStyle(color: AppColors.charcoal500, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah Top Up (Rp)', prefixIcon: Icon(Icons.payments_outlined)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kirim Permintaan'),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Riwayat Permintaan', style: TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          depositsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.emerald600))),
            error: (e, _) => Text('Gagal memuat: $e', style: const TextStyle(color: Colors.red)),
            data: (deposits) {
              if (deposits.isEmpty) return const Text('Belum ada permintaan top up.', style: TextStyle(color: AppColors.charcoal500));
              return Column(
                children: deposits.map((d) {
                  final status = d['status'] as String;
                  final (label, color) = switch (status) {
                    'approved' => ('Disetujui', AppColors.emerald600),
                    'rejected' => ('Ditolak', Colors.red),
                    _ => ('Menunggu', Colors.orange),
                  };
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Formatters.rupiah((d['amount'] as num).toInt()), style: const TextStyle(color: AppColors.charcoal900, fontWeight: FontWeight.w600)),
                              Text(Formatters.dateTime(DateTime.parse(d['created_at'] as String)), style: const TextStyle(color: AppColors.charcoal500, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
