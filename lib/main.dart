import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/lock_provider.dart';
import 'core/router/app_router.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/security/pin_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: KasirProApp()));
}

class KasirProApp extends ConsumerWidget {
  const KasirProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kasir Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => _LockOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Menumpuk layar kunci PIN di atas rute manapun yang sedang aktif ketika
/// `lockProvider` bernilai true — dan otomatis mengunci saat aplikasi
/// kembali dari background (mis. kasir taruh HP, orang lain buka lagi).
class _LockOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const _LockOverlay({required this.child});

  @override
  ConsumerState<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends ConsumerState<_LockOverlay> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Kunci otomatis saat app masuk background, TAPI hanya jika staff
      // sudah pernah mengatur PIN (kalau belum, tidak ada cara membuka lagi).
      final hasPin = ref.read(hasStaffPinProvider).valueOrNull;
      if (hasPin == true) ref.read(lockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(lockProvider);
    return Stack(
      children: [
        widget.child,
        if (isLocked) const PinLockScreen(),
      ],
    );
  }
}
