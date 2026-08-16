import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import 'app_sidebar.dart';

/// Lebar layar di atas ini dianggap tablet/desktop -> pakai sidebar kiri.
/// Di bawah ini (HP) -> pakai bottom navigation bar seperti biasa.
const double _wideBreakpoint = 900;

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _kasirNavGroups = [
    NavGroup(items: [
      NavItem('/pos', Icons.point_of_sale_outlined, 'Kasir', activeIcon: Icons.point_of_sale_rounded),
    ]),
    NavGroup(label: 'Aktivitas', items: [
      NavItem('/history', Icons.receipt_long_outlined, 'Riwayat', activeIcon: Icons.receipt_long_rounded),
      NavItem('/shift', Icons.access_time_outlined, 'Shift', activeIcon: Icons.access_time_filled_rounded),
    ]),
    NavGroup(label: 'Lainnya', items: [
      NavItem('/printer-settings', Icons.print_outlined, 'Printer', activeIcon: Icons.print_rounded),
    ]),
  ];

  static const _managerNavGroups = [
    NavGroup(items: [
      NavItem('/pos', Icons.point_of_sale_outlined, 'Kasir', activeIcon: Icons.point_of_sale_rounded),
      NavItem('/dashboard', Icons.dashboard_outlined, 'Dashboard', activeIcon: Icons.dashboard_rounded),
    ]),
    NavGroup(label: 'Manajemen', items: [
      NavItem('/products', Icons.inventory_2_outlined, 'Produk', activeIcon: Icons.inventory_2_rounded),
      NavItem('/reports', Icons.bar_chart_outlined, 'Laporan', activeIcon: Icons.bar_chart_rounded),
      NavItem('/history', Icons.receipt_long_outlined, 'Riwayat', activeIcon: Icons.receipt_long_rounded),
    ]),
    NavGroup(label: 'Lainnya', items: [
      NavItem('/shift', Icons.access_time_outlined, 'Shift', activeIcon: Icons.access_time_filled_rounded),
      NavItem('/printer-settings', Icons.print_outlined, 'Printer', activeIcon: Icons.print_rounded),
    ]),
  ];

  // Versi flat (untuk bottom nav di HP, tanpa grouping)
  static const _kasirTabsFlat = [
    NavItem('/pos', Icons.point_of_sale_outlined, 'Kasir', activeIcon: Icons.point_of_sale_rounded),
    NavItem('/history', Icons.receipt_long_outlined, 'Riwayat', activeIcon: Icons.receipt_long_rounded),
    NavItem('/shift', Icons.access_time_outlined, 'Shift', activeIcon: Icons.access_time_filled_rounded),
  ];

  static const _managerTabsFlat = [
    NavItem('/pos', Icons.point_of_sale_outlined, 'Kasir', activeIcon: Icons.point_of_sale_rounded),
    NavItem('/dashboard', Icons.dashboard_outlined, 'Dashboard', activeIcon: Icons.dashboard_rounded),
    NavItem('/products', Icons.inventory_2_outlined, 'Produk', activeIcon: Icons.inventory_2_rounded),
    NavItem('/reports', Icons.bar_chart_outlined, 'Laporan', activeIcon: Icons.bar_chart_rounded),
    NavItem('/history', Icons.receipt_long_outlined, 'Riwayat', activeIcon: Icons.receipt_long_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(currentStaffProvider);

    return staffAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Gagal memuat sesi: $e')),
      ),
      data: (staff) {
        final isManager = staff?.role.canManage ?? false;
        final location = GoRouterState.of(context).matchedLocation;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;

            if (isWide) {
              final groups = isManager ? _managerNavGroups : _kasirNavGroups;
              return Scaffold(
                body: Row(
                  children: [
                    AppSidebar(groups: groups, currentLocation: location),
                    Expanded(child: SafeArea(child: child)),
                  ],
                ),
              );
            }

            final tabs = isManager ? _managerTabsFlat : _kasirTabsFlat;
            final currentIndex = tabs.indexWhere((t) => location.startsWith(t.path));

            return Scaffold(
              body: SafeArea(child: child),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: currentIndex < 0 ? 0 : currentIndex,
                onTap: (i) => context.go(tabs[i].path),
                items: [
                  for (final tab in tabs)
                    BottomNavigationBarItem(icon: Icon(tab.icon), activeIcon: Icon(tab.activeIcon ?? tab.icon), label: tab.label),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
