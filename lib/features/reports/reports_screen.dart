import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'providers/report_export_service.dart';
import 'providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportsSummaryProvider);
    final storeAsync = ref.watch(currentStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan 7 Hari'),
        actions: [
          if (summaryAsync.hasValue)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Export',
              onSelected: (v) async {
                final summary = summaryAsync.value!;
                final storeName = storeAsync.value?.name ?? 'Kasir Pro';
                final from = summary.daily.isNotEmpty ? summary.daily.first.date : DateTime.now();
                final to = summary.daily.isNotEmpty ? summary.daily.last.date : DateTime.now();
                try {
                  if (v == 'pdf') {
                    await ReportExportService.instance
                        .exportPdf(storeName: storeName, summary: summary, from: from, to: to);
                  } else {
                    await ReportExportService.instance
                        .exportExcel(storeName: storeName, summary: summary, from: from, to: to);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
                  }
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                PopupMenuItem(value: 'excel', child: Text('Export Excel')),
              ],
            ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
        error: (e, _) => Center(child: Text('Gagal memuat laporan: $e')),
        data: (summary) {
          final maxY = summary.daily.fold<int>(1, (m, d) => d.revenue > m ? d.revenue : m).toDouble();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total Omzet',
                      value: Formatters.rupiah(summary.totalRevenue),
                      color: AppColors.emerald600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Laba Kotor',
                      value: Formatters.rupiah(summary.totalProfit),
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: 'Total Transaksi',
                value: '${summary.totalTransactions} transaksi',
                color: AppColors.charcoal700,
                fullWidth: true,
              ),
              const SizedBox(height: 24),
              const Text('Omzet per Hari', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: maxY * 1.2,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= summary.daily.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(Formatters.dayLabel(summary.daily[i].date),
                                  style: const TextStyle(fontSize: 11, color: AppColors.charcoal500)),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final day = summary.daily[group.x.toInt()];
                          return BarTooltipItem(
                            '${Formatters.date(day.date)}\n${Formatters.rupiah(day.revenue)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < summary.daily.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: summary.daily[i].revenue.toDouble(),
                              color: AppColors.emerald600,
                              width: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Rincian Harian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              ...summary.daily.reversed.map((d) => Card(
                    child: ListTile(
                      title: Text(Formatters.date(d.date)),
                      subtitle: Text('${d.transactionCount} transaksi'),
                      trailing: Text(Formatters.rupiah(d.revenue),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald700)),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _MetricCard({required this.label, required this.value, required this.color, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.charcoal500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: fullWidth ? 20 : 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
