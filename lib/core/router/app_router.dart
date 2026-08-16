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

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (_, __) => authNotifier.value++);

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(currentUserProvider) != null;
      final isLoggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/pos';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/products', builder: (context, state) => const ProductsScreen(), routes: [
            GoRoute(path: 'new', builder: (context, state) => const ProductFormScreen()),
            GoRoute(path: 'edit/:id', builder: (context, state) => ProductFormScreen(productId: state.pathParameters['id'])),
          ]),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/history', builder: (context, state) => const HistoryScreen(), routes: [
            GoRoute(path: ':id', builder: (context, state) => TransactionDetailScreen(transactionId: state.pathParameters['id']!)),
          ]),
          GoRoute(path: '/shift', builder: (context, state) => const ShiftScreen()),
          GoRoute(path: '/printer-settings', builder: (context, state) => const PrinterSettingsScreen()),
          GoRoute(path: '/accounting', builder: (context, state) => const AccountingScreen()),
        ],
      ),
    ],
  );
});
