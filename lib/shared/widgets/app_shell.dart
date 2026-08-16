import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import 'app_sidebar.dart';

const double _wideBreakpoint=900;

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key,required this.child});
  static const _kasirNavGroups=[
    NavGroup(items:[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded)]),
    NavGroup(label:'Aktivitas',items:[NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded),NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded)]),
    NavGroup(label:'Lainnya',items:[NavItem('/offline',Icons.cloud_off_outlined,'Offline',activeIcon:Icons.cloud_done_rounded),NavItem('/printer-settings',Icons.print_outlined,'Printer',activeIcon:Icons.print_rounded)])];
  static const _managerNavGroups=[
    NavGroup(items:[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/dashboard',Icons.dashboard_outlined,'Dashboard',activeIcon:Icons.dashboard_rounded),NavItem('/operations',Icons.analytics_outlined,'Operasional',activeIcon:Icons.analytics_rounded)]),
    NavGroup(label:'Manajemen',items:[NavItem('/products',Icons.inventory_2_outlined,'Produk',activeIcon:Icons.inventory_2_rounded),NavItem('/reports',Icons.bar_chart_outlined,'Laporan',activeIcon:Icons.bar_chart_rounded),NavItem('/accounting',Icons.account_balance_outlined,'Accounting',activeIcon:Icons.account_balance_rounded),NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded)]),
    NavGroup(label:'Sistem',items:[NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded),NavItem('/offline',Icons.cloud_off_outlined,'Offline',activeIcon:Icons.cloud_done_rounded),NavItem('/printer-settings',Icons.print_outlined,'Printer',activeIcon:Icons.print_rounded)])];
  static const _kasirTabsFlat=[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded),NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded),NavItem('/offline',Icons.cloud_off_outlined,'Offline',activeIcon:Icons.cloud_done_rounded)];
  static const _managerTabsFlat=[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/dashboard',Icons.dashboard_outlined,'Dashboard',activeIcon:Icons.dashboard_rounded),NavItem('/products',Icons.inventory_2_outlined,'Produk',activeIcon:Icons.inventory_2_rounded),NavItem('/operations',Icons.analytics_outlined,'Operasional',activeIcon:Icons.analytics_rounded),NavItem('/reports',Icons.bar_chart_outlined,'Laporan',activeIcon:Icons.bar_chart_rounded)];
  @override Widget build(BuildContext context,WidgetRef ref){final staffAsync=ref.watch(currentStaffProvider);return staffAsync.when(loading:()=>const Scaffold(body:Center(child:CircularProgressIndicator(color:AppColors.emerald600))),error:(e,_)=>Scaffold(body:Center(child:Text('Gagal memuat sesi: $e'))),data:(staff){final manager=staff?.role.canManage??false;final location=GoRouterState.of(context).matchedLocation;return LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=_wideBreakpoint;if(wide){return Scaffold(body:Row(children:[AppSidebar(groups:manager?_managerNavGroups:_kasirNavGroups,currentLocation:location),Expanded(child:SafeArea(child:child))]));}final tabs=manager?_managerTabsFlat:_kasirTabsFlat;final idx=tabs.indexWhere((t)=>location.startsWith(t.path));return Scaffold(body:SafeArea(child:child),bottomNavigationBar:BottomNavigationBar(currentIndex:idx<0?0:idx,onTap:(i)=>context.go(tabs[i].path),items:[for(final t in tabs)BottomNavigationBarItem(icon:Icon(t.icon),activeIcon:Icon(t.activeIcon??t.icon),label:t.label)]));});}});
  }
}
