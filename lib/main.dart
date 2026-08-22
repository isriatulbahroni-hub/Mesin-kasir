import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/lock_provider.dart';
import 'core/router/app_router.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/security/pin_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kalau ada widget yang gagal di-build (exception di dalam build()), Flutter
  // biasanya nampilin layar generik/kosong di release mode - susah didebug.
  // Override ini bikin error ASLINYA selalu kelihatan di layar, baik pas
  // development maupun pas testing APK di HP. Murni API bawaan Flutter,
  // tidak nambah dependency, aman dipakai di production.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

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
