import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/approval_request.dart';
import 'providers/approval_provider.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  static const _requestTypes = [
    'discount', 'void', 'refund', 'stock_adjustment', 'cash_out', 'price_change',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(approvalRequestsProvider);
    final staffAsync = ref.watch(currentStaffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ajukan Approval',
            onPressed: () => _showRequestDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(approvalRequestsProvider),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat: $e')),
          data: (requests) {
            if (requests.isEmpty) {
              return const Center(child: Text('Belum ada permintaan approval.'));
            }
            final isAdmin = staffAsync.value?.role.canManage ?? false;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, i) {
                final r = requests[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.typeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            _StatusChip(status: r.status, label: r.statusLabel),
                          ],
                        ),
                        if (r.amount != null) ...[
                          const SizedBox(height: 4),
                          Text(Formatters.rupiah(r.amount!),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald700)),
                        ],
                        if (r.reason != null) ...[
                          const SizedBox(height: 4),
                          Text(r.reason!, style: const TextStyle(color: AppColors.charcoal500, fontSize: 12.5)),
                        ],
                        const SizedBox(height: 4),
                        Text(Formatters.dateTime(r.createdAt),
                            style: const TextStyle(color: AppColors.charcoal300, fontSize: 11)),
                        if (r.status == 'pending' && isAdmin) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                  onPressed: () => _decide(context, ref, r, false),
                                  child: const Text('Tolak'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _decide(context, ref, r, true),
                                  child: const Text('Setujui'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _decide(BuildContext context, WidgetRef ref, ApprovalRequest r, bool approve) async {
    final error = await ref.read(approvalControllerProvider.notifier).decide(
          requestId: r.id,
          approve: approve,
        );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _showRequestDialog(BuildContext context, WidgetRef ref) {
    String type = _requestTypes.first;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ajukan Approval'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: [
                  for (final t in _requestTypes)
                    DropdownMenuItem(value: t, child: Text(ApprovalRequest(
                      id: '', storeId: '', requestedBy: '', requestType: t, status: 'pending',
                      createdAt: DateTime.now(),
                    ).typeLabel)),
                ],
                onChanged: (v) => setState(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nominal (opsional)', prefixText: 'Rp '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Alasan'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final error = await ref.read(approvalControllerProvider.notifier).requestApproval(
                      requestType: type,
                      amount: int.tryParse(amountCtrl.text.trim()),
                      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                    );
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;
  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'approved' => (AppColors.successBg, AppColors.success),
      'rejected' => (AppColors.dangerBg, AppColors.danger),
      'cancelled' => (AppColors.sand200, AppColors.charcoal500),
      _ => (AppColors.warningBg, AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
