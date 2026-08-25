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
    NavGroup(label:'Aktivitas',items:[NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded),NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded),NavItem('/customers',Icons.people_outline_rounded,'Pelanggan',activeIcon:Icons.people_rounded)]),
    NavGroup(label:'Lainnya',items:[NavItem('/pulsa',Icons.smartphone_outlined,'Pulsa & Digital',activeIcon:Icons.smartphone_rounded),NavItem('/kitchen',Icons.soup_kitchen_outlined,'Kitchen',activeIcon:Icons.soup_kitchen_rounded),NavItem('/offline',Icons.cloud_off_outlined,'Offline',activeIcon:Icons.cloud_done_rounded),NavItem('/printer-settings',Icons.print_outlined,'Printer',activeIcon:Icons.print_rounded)])];
  static const _managerNavGroups=[
    NavGroup(items:[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/dashboard',Icons.dashboard_outlined,'Dashboard',activeIcon:Icons.dashboard_rounded),NavItem('/operations',Icons.analytics_outlined,'Operasional',activeIcon:Icons.analytics_rounded)]),
    NavGroup(label:'Manajemen',items:[NavItem('/products',Icons.inventory_2_outlined,'Produk',activeIcon:Icons.inventory_2_rounded),NavItem('/pulsa',Icons.smartphone_outlined,'Pulsa & Digital',activeIcon:Icons.smartphone_rounded),NavItem('/inventory',Icons.warehouse_outlined,'Inventory',activeIcon:Icons.warehouse_rounded),NavItem('/customers',Icons.people_outline_rounded,'Pelanggan',activeIcon:Icons.people_rounded),NavItem('/promotions',Icons.local_offer_outlined,'Promo',activeIcon:Icons.local_offer_rounded),NavItem('/reports',Icons.bar_chart_outlined,'Laporan',activeIcon:Icons.bar_chart_rounded),NavItem('/accounting',Icons.account_balance_outlined,'Accounting',activeIcon:Icons.account_balance_rounded),NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded)]),
    NavGroup(label:'Sistem',items:[NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded),NavItem('/kitchen',Icons.soup_kitchen_outlined,'Kitchen',activeIcon:Icons.soup_kitchen_rounded),NavItem('/approvals',Icons.fact_check_outlined,'Approval',activeIcon:Icons.fact_check_rounded),NavItem('/devices',Icons.devices_outlined,'Device',activeIcon:Icons.devices_rounded),NavItem('/qris-settings',Icons.qr_code_2_outlined,'QRIS',activeIcon:Icons.qr_code_2_rounded),NavItem('/offline',Icons.cloud_off_outlined,'Offline',activeIcon:Icons.cloud_done_rounded),NavItem('/printer-settings',Icons.print_outlined,'Printer',activeIcon:Icons.print_rounded)])];
  static const _kasirTabsFlat=[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/history',Icons.receipt_long_outlined,'Riwayat',activeIcon:Icons.receipt_long_rounded),NavItem('/customers',Icons.people_outline_rounded,'Pelanggan',activeIcon:Icons.people_rounded),NavItem('/shift',Icons.access_time_outlined,'Shift',activeIcon:Icons.access_time_filled_rounded)];
  static const _managerTabsFlat=[NavItem('/pos',Icons.point_of_sale_outlined,'Kasir',activeIcon:Icons.point_of_sale_rounded),NavItem('/dashboard',Icons.dashboard_outlined,'Dashboard',activeIcon:Icons.dashboard_rounded),NavItem('/products',Icons.inventory_2_outlined,'Produk',activeIcon:Icons.inventory_2_rounded),NavItem('/customers',Icons.people_outline_rounded,'Pelanggan',activeIcon:Icons.people_rounded)];
  static const _moreTab=NavItem('__more__',Icons.more_horiz_rounded,'Lainnya',activeIcon:Icons.more_horiz_rounded);
  @override Widget build(BuildContext context,WidgetRef ref){final staffAsync=ref.watch(currentStaffProvider);return staffAsync.when(loading:()=>const Scaffold(body:Center(child:CircularProgressIndicator(color:AppColors.emerald600))),error:(e,_)=>Scaffold(body:Center(child:Text('Gagal memuat sesi: $e'))),data:(staff){final manager=staff?.role.canManage??false;final location=GoRouterState.of(context).matchedLocation;return LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=_wideBreakpoint;final groups=manager?_managerNavGroups:_kasirNavGroups;if(wide){return Scaffold(body:Row(children:[AppSidebar(groups:groups,currentLocation:location),Expanded(child:SafeArea(child:child))]));}
    final directTabs=manager?_managerTabsFlat:_kasirTabsFlat;
    final directIdx=directTabs.indexWhere((t)=>location.startsWith(t.path));
    // Tab 'Lainnya' aktif kalau lokasi saat ini bukan salah satu dari 4 tab
    // langsung — mencegah 'Kasir' salah nyala saat sebenarnya di Promo/dst.
    final activeIdx=directIdx>=0?directIdx:directTabs.length;
    return Scaffold(
      body:SafeArea(child:child),
      bottomNavigationBar:BottomNavigationBar(
        type:BottomNavigationBarType.fixed,
        currentIndex:activeIdx,
        onTap:(i){
          if(i<directTabs.length){context.go(directTabs[i].path);}
          else{_showMoreSheet(context,groups,directTabs,location);}
        },
        items:[
          for(final t in directTabs)BottomNavigationBarItem(icon:Icon(t.icon),activeIcon:Icon(t.activeIcon??t.icon),label:t.label),
          BottomNavigationBarItem(icon:Icon(_moreTab.icon),activeIcon:Icon(_moreTab.activeIcon??_moreTab.icon),label:_moreTab.label),
        ],
      ),
    );});});
  }

  void _showMoreSheet(BuildContext context,List<NavGroup> groups,List<NavItem> directTabs,String currentLocation){
    final directPaths=directTabs.map((t)=>t.path).toSet();
    showModalBottomSheet(context:context,backgroundColor:AppColors.surface,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))),builder:(ctx)=>SafeArea(
      child:ListView(
        shrinkWrap:true,
        padding:const EdgeInsets.symmetric(vertical:12),
        children:[
          for(final group in groups)
            if(group.items.any((i)=>!directPaths.contains(i.path)))...[
              if(group.label!=null)Padding(padding:const EdgeInsets.fromLTRB(20,12,20,4),child:Text(group.label!,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:AppColors.charcoal500))),
              for(final item in group.items)
                if(!directPaths.contains(item.path))
                  ListTile(
                    leading:Icon(currentLocation.startsWith(item.path)?(item.activeIcon??item.icon):item.icon,color:currentLocation.startsWith(item.path)?AppColors.emerald600:null),
                    title:Text(item.label),
                    onTap:(){Navigator.pop(ctx);context.go(item.path);},
                  ),
            ],
        ],
      ),
    ));
  }
}
