import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/product_grid.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(currentStoreProvider);
    final staffAsync = ref.watch(currentStaffProvider);
    final shiftAsync = ref.watch(activeShiftProvider);
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: storeAsync.when(
          data: (store) => Text(store?.name ?? 'Kasir Pro'),
          loading: () => const Text('Kasir Pro'),
          error: (_, __) => const Text('Kasir Pro'),
        ),
        actions: [
          staffAsync.maybeWhen(
            data: (staff) => staff != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Chip(
                        label: Text(staff.role.label),
                        backgroundColor: AppColors.emerald100,
                        labelStyle: const TextStyle(
                            color: AppColors.emerald700, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          shiftAsync.maybeWhen(
            data: (shift) => shift == null
                ? _ShiftClosedBanner(onOpen: () => context.go('/shift'))
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: isWide
                ? const Row(
                    children: [
                      Expanded(flex: 3, child: ProductGrid()),
                      SizedBox(width: 340, child: CartPanel()),
                    ],
                  )
                : const _MobilePosLayout(),
          ),
        ],
      ),
    );
  }
}

class _ShiftClosedBanner extends StatelessWidget {
  final VoidCallback onOpen;
  const _ShiftClosedBanner({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Shift kasir belum dibuka. Buka shift dulu sebelum bertransaksi.',
                style: TextStyle(fontSize: 12.5, color: AppColors.charcoal900)),
          ),
          TextButton(onPressed: onOpen, child: const Text('Buka Shift')),
        ],
      ),
    );
  }
}

/// Layar sempit (HP): produk full-width, keranjang dibuka lewat tombol
/// mengambang di kanan-bawah agar tetap satu tangan.
class _MobilePosLayout extends ConsumerWidget {
  const _MobilePosLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const ProductGrid(),
        _CartFab(),
      ],
    );
  }
}

class _CartFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.lines.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald600,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const FractionallySizedBox(
            heightFactor: 0.85,
            child: CartPanel(),
          ),
        ),
        icon: const Icon(Icons.shopping_cart_rounded),
        label: Text('${cart.itemCount} item'),
      ),
    );
  }
}
