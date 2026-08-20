import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/transaction_detail_screen.dart';
import '../../features/shift/shift_screen.dart';
import '../../features/printer/printer_settings_screen.dart';
import '../../features/accounting/accounting_screen.dart';
import '../../features/offline/offline_sync_screen.dart';
import '../../features/operations/operations_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/promotions/promotions_screen.dart';
import '../../features/promotions/promotion_form_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/kitchen/kitchen_screen.dart';
import '../../features/approvals/approvals_screen.dart';
import '../../features/devices/devices_screen.dart';
import '../../features/qris/qris_settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (_, __) => authNotifier.value++);
  return GoRouter(
    initialLocation:'/pos', refreshListenable:authNotifier,
    redirect:(context,state){final logged=ref.read(currentUserProvider)!=null;final login=state.matchedLocation=='/login';if(!logged&&!login)return '/login';if(logged&&login)return '/pos';return null;},
    routes:[
      GoRoute(path:'/login',builder:(context,state)=>const LoginScreen()),
      ShellRoute(builder:(context,state,child)=>AppShell(child:child),routes:[
        GoRoute(path:'/pos',builder:(context,state)=>const PosScreen()),
        GoRoute(path:'/dashboard',builder:(context,state)=>const DashboardScreen()),
        GoRoute(path:'/operations',builder:(context,state)=>const OperationsScreen()),
        GoRoute(path:'/products',builder:(context,state)=>const ProductsScreen(),routes:[GoRoute(path:'new',builder:(context,state)=>const ProductFormScreen()),GoRoute(path:'edit/:id',builder:(context,state)=>ProductFormScreen(productId:state.pathParameters['id']))]),
        GoRoute(path:'/reports',builder:(context,state)=>const ReportsScreen()),
        GoRoute(path:'/history',builder:(context,state)=>const HistoryScreen(),routes:[GoRoute(path:':id',builder:(context,state)=>TransactionDetailScreen(transactionId:state.pathParameters['id']!))]),
        GoRoute(path:'/shift',builder:(context,state)=>const ShiftScreen()),
        GoRoute(path:'/printer-settings',builder:(context,state)=>const PrinterSettingsScreen()),
        GoRoute(path:'/accounting',builder:(context,state)=>const AccountingScreen()),
        GoRoute(path:'/offline',builder:(context,state)=>const OfflineSyncScreen()),
        GoRoute(path:'/inventory',builder:(context,state)=>const InventoryScreen()),
        GoRoute(path:'/kitchen',builder:(context,state)=>const KitchenScreen()),
        GoRoute(path:'/approvals',builder:(context,state)=>const ApprovalsScreen()),
        GoRoute(path:'/devices',builder:(context,state)=>const DevicesScreen()),
        GoRoute(path:'/qris-settings',builder:(context,state)=>const QrisSettingsScreen()),
        GoRoute(path:'/customers',builder:(context,state)=>const CustomersScreen(),routes:[
          GoRoute(path:'new',builder:(context,state)=>const CustomerFormScreen()),
          GoRoute(path:'edit/:id',builder:(context,state)=>CustomerFormScreen(customerId:state.pathParameters['id'])),
          GoRoute(path:':id',builder:(context,state)=>CustomerDetailScreen(customerId:state.pathParameters['id']!)),
        ]),
        GoRoute(path:'/promotions',builder:(context,state)=>const PromotionsScreen(),routes:[
          GoRoute(path:'new',builder:(context,state)=>const PromotionFormScreen()),
        ]),
      ]),
    ],
  );
});
