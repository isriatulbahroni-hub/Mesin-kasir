import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/lock_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/security/pin_setup_screen.dart';

class NavGroup {
  final String? label;
  final List<NavItem> items;
  const NavGroup({this.label, required this.items});
}

class NavItem {
  final String path;
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  const NavItem(this.path, this.icon, this.label, {this.activeIcon});
}

/// Sidebar kiri: logo, nama toko, grup navigasi, dan footer profil staff.
/// Dipakai hanya di layar lebar (tablet/desktop) — di HP tetap pakai
/// bottom navigation bar supaya tetap nyaman dipakai satu tangan.
class AppSidebar extends ConsumerWidget {
  final List<NavGroup> groups;
  final String currentLocation;

  const AppSidebar({super.key, required this.groups, required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(currentStoreProvider);
    final staffAsync = ref.watch(currentStaffProvider);

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.emerald100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emerald600, width: 1.2),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: AppColors.neonGreenBright, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          children: [
                            TextSpan(text: 'Kasir', style: TextStyle(color: AppColors.textPrimary)),
                            TextSpan(text: 'Pro', style: TextStyle(color: AppColors.neonGreenBright)),
                          ],
                        ),
                      ),
                      storeAsync.maybeWhen(
                        data: (store) => Text(
                          store?.name ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                for (final group in groups) ...[
                  if (group.label != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                      child: Text(
                        group.label!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  for (final item in group.items)
                    _SidebarTile(
                      item: item,
                      selected: currentLocation.startsWith(item.path),
                      onTap: () => context.go(item.path),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          staffAsync.maybeWhen(
            data: (staff) => Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.emerald100,
                    child: Text(
                      (staff?.fullName.isNotEmpty ?? false) ? staff!.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.neonGreenBright, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff?.fullName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text(staff?.role.label ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  _LockButton(),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 19, color: AppColors.textSecondary),
                    tooltip: 'Keluar',
                    onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LockButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPinAsync = ref.watch(hasStaffPinProvider);
    final hasPin = hasPinAsync.valueOrNull ?? false;
    return IconButton(
      icon: Icon(hasPin ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 19, color: AppColors.textSecondary),
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

class _SidebarTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.emerald100 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 19,
                  color: selected ? AppColors.neonGreenBright : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(color: AppColors.neonGreen, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
