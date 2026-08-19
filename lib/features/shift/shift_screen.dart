import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/shift.dart';
import 'providers/shift_provider.dart';

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shift Kasir')),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shift) => shift == null
            ? _OpenShiftForm(onOpened: () => ref.invalidate(activeShiftProvider))
            : _ActiveShiftView(shift: shift),
      ),
    );
  }
}

class _OpenShiftForm extends ConsumerStatefulWidget {
  final VoidCallback onOpened;
  const _OpenShiftForm({required this.onOpened});

  @override
  ConsumerState<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends ConsumerState<_OpenShiftForm> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_clock_rounded, size: 48, color: AppColors.charcoal300),
              const SizedBox(height: 16),
              Text('Shift belum dibuka',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Masukkan modal kas awal untuk membuka shift.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.charcoal500)),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kas awal (modal)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Buka Shift'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final value = int.tryParse(_ctrl.text.trim()) ?? 0;
    setState(() => _submitting = true);
    final error = await ref.read(shiftControllerProvider.notifier).openShift(openingCash: value);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      widget.onOpened();
    }
  }
}

class _ActiveShiftView extends ConsumerStatefulWidget {
  final Shift shift;
  const _ActiveShiftView({required this.shift});

  @override
  ConsumerState<_ActiveShiftView> createState() => _ActiveShiftViewState();
}

class _ActiveShiftViewState extends ConsumerState<_ActiveShiftView> {
  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final duration = DateTime.now().difference(shift.openedAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: AppColors.emerald500, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Text('Shift Aktif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow('Dibuka', Formatters.dateTime(shift.openedAt)),
                  _InfoRow('Durasi', '${duration.inHours} jam ${duration.inMinutes % 60} menit'),
                  _InfoRow('Kas awal', Formatters.rupiah(shift.openingCash)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashMovementDialog(context, 'cash_in'),
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.emerald600),
                  label: const Text('Kas Masuk'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashMovementDialog(context, 'cash_out'),
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.warning),
                  label: const Text('Kas Keluar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showCashMovementDialog(context, 'expense'),
            icon: const Icon(Icons.receipt_outlined, color: AppColors.danger),
            label: const Text('Catat Pengeluaran'),
          ),
          const SizedBox(height: 20),
          const Text('Riwayat Kas Shift Ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final movementsAsync = ref.watch(cashMovementsProvider(shift.id));
              return movementsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('Gagal memuat: $e'),
                data: (movements) {
                  if (movements.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Belum ada catatan kas masuk/keluar.',
                          style: TextStyle(color: AppColors.charcoal500)),
                    );
                  }
                  return Column(
                    children: [
                      for (final m in movements)
                        Card(
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              m.type == 'cash_in' ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                              color: m.type == 'cash_in' ? AppColors.emerald600 : AppColors.warning,
                            ),
                            title: Text(m.label),
                            subtitle: m.note != null ? Text(m.note!) : null,
                            trailing: Text(
                              '${m.type == 'cash_in' ? '+' : '-'} ${Formatters.rupiah(m.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: m.type == 'cash_in' ? AppColors.emerald600 : AppColors.warning,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showCloseShiftDialog(context),
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('Tutup Shift'),
          ),
        ],
      ),
    );
  }

  void _showCashMovementDialog(BuildContext context, String type) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final title = switch (type) {
      'cash_in' => 'Catat Kas Masuk',
      'cash_out' => 'Catat Kas Keluar',
      _ => 'Catat Pengeluaran',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              final error = await ref.read(shiftControllerProvider.notifier).addCashMovement(
                    shiftId: widget.shift.id,
                    type: type,
                    amount: amount,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
              if (!mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan.')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hitung fisik uang kas di laci sekarang, lalu masukkan totalnya:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Kas fisik saat ini', prefixText: 'Rp '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final closingCash = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              final error = await ref.read(shiftControllerProvider.notifier).closeShift(
                    shiftId: widget.shift.id,
                    closingCash: closingCash,
                  );
              if (!mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              } else {
                ref.invalidate(activeShiftProvider);
                _showResultAfterClose(closingCash);
              }
            },
            child: const Text('Tutup Shift'),
          ),
        ],
      ),
    );
  }

  void _showResultAfterClose(int closingCash) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.emerald600, size: 48),
        title: const Text('Shift ditutup'),
        content: const Text('Selisih kas sudah dicatat di riwayat shift.'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.charcoal500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
