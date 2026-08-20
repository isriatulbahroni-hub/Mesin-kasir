import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/lock_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../security/pin_setup_screen.dart';
import 'barcode_lookup.dart';
import 'providers/cart_provider.dart';
import 'providers/held_cart_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/held_carts_sheet.dart';
import 'widgets/product_grid.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

/// Scanner hardware (USB/Bluetooth keyboard-wedge) "mengetik" barcode lalu
/// menekan Enter, jauh lebih cepat daripada ketikan manusia (biasanya <30ms
/// antar-karakter vs >80ms untuk mengetik biasa). Kita bedakan keduanya dari
/// kecepatan ketik, bukan dari fokus widget, supaya tetap berfungsi walau
/// tidak ada TextField yang sedang fokus dan tidak mengganggu pencarian
/// produk manual di ProductGrid.
class _PosScreenState extends ConsumerState<PosScreen> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyAt;
  static const _maxGap = Duration(milliseconds: 60);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final now = DateTime.now();
    final gap = _lastKeyAt == null ? null : now.difference(_lastKeyAt!);
    _lastKeyAt = now;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString();
      _buffer.clear();
      // Ketikan manusia yang kebetulan diakhiri Enter (mis. di kolom lain)
      // akan punya jeda antar-karakter yang jauh lebih lambat, jadi diabaikan.
      if (code.length >= 3 && gap != null && gap <= _maxGap) {
        handleScannedCode(context, ref, code);
      }
      return false;
    }

    var char = event.character;
    if (char == null || char.isEmpty) {
      char = _digitFromLogicalKey(event.logicalKey);
    }
    if (char == null || char.isEmpty) return false;
    if (gap != null && gap > _maxGap) _buffer.clear();
    _buffer.write(char);
    // Jaga buffer tetap wajar untuk mencegah menumpuk tanpa batas kalau tidak
    // pernah diakhiri Enter (mis. saat mengetik biasa di kolom lain).
    if (_buffer.length > 64) _buffer.clear();
    return false;
  }

  /// Fallback untuk scanner hardware yang kadang tidak mengisi
  /// [KeyEvent.character] pada digit (umum di beberapa mode HID numpad).
  static final _digitKeys = {
    LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.digit1: '1', LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.digit2: '2', LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.digit3: '3', LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.digit5: '5', LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.digit7: '7', LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.digit8: '8', LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.digit9: '9', LogicalKeyboardKey.numpad9: '9',
  };

  String? _digitFromLogicalKey(LogicalKeyboardKey key) => _digitKeys[key];

  @override
  Widget build(BuildContext context) {
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
          _HeldCartsButton(),
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
          _PosLockButton(),
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

class _PosLockButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPinAsync = ref.watch(hasStaffPinProvider);
    final hasPin = hasPinAsync.valueOrNull ?? false;
    return IconButton(
      icon: Icon(hasPin ? Icons.lock_outline_rounded : Icons.lock_open_rounded),
      tooltip: hasPin ? 'Kunci layar' : 'Atur PIN kunci layar',
      onPressed: () async {
        if (hasPin) {
          ref.read(lockProvider.notifier).lock();
        } else {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
        }
      },
    );
  }
}

class _HeldCartsButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(heldCartsProvider).valueOrNull?.length ?? 0;
    return IconButton(
      tooltip: 'Transaksi tertahan',
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.pause_circle_outline_rounded),
      ),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const HeldCartsSheet(),
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
