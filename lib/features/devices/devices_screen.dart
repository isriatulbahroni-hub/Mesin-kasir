import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/device.dart';
import 'providers/device_provider.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    // Otomatis daftarkan/update "last seen" device ini setiap layar dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceControllerProvider.notifier).registerOrTouchThisDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(deviceListProvider);
    final currentKeyAsync = ref.watch(currentDeviceKeyProvider);
    final staffAsync = ref.watch(currentStaffProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Management')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(deviceListProvider),
        child: devicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
          error: (e, _) => Center(child: Text('Gagal memuat: $e')),
          data: (devices) {
            if (devices.isEmpty) {
              return const Center(child: Text('Belum ada device terdaftar.'));
            }
            final currentKey = currentKeyAsync.value;
            final isAdmin = staffAsync.value?.role.canManage ?? false;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final d = devices[i];
                final isThis = d.deviceKey == currentKey;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      d.platform == 'iOS' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                      color: d.isRevoked
                          ? AppColors.charcoal300
                          : isThis
                              ? AppColors.emerald600
                              : AppColors.charcoal500,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(d.deviceName, overflow: TextOverflow.ellipsis)),
                        if (isThis) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: AppColors.emerald100, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Device Ini',
                                style: TextStyle(fontSize: 10, color: AppColors.neonGreenBright, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      d.isRevoked
                          ? 'Akses dicabut'
                          : d.lastSeenAt != null
                              ? 'Terakhir aktif: ${Formatters.dateTime(d.lastSeenAt!)}'
                              : 'Belum pernah aktif',
                      style: TextStyle(color: d.isRevoked ? AppColors.danger : AppColors.charcoal500, fontSize: 12),
                    ),
                    trailing: (isAdmin && !d.isRevoked && !isThis)
                        ? IconButton(
                            icon: const Icon(Icons.block_rounded, color: AppColors.danger),
                            tooltip: 'Cabut akses',
                            onPressed: () => _confirmRevoke(context, d),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cabut akses "${device.deviceName}"?'),
        content: const Text('Device ini tidak akan bisa dipakai lagi untuk sinkronisasi offline sampai didaftarkan ulang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await ref.read(deviceControllerProvider.notifier).revokeDevice(device.id);
              if (!mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
            },
            child: const Text('Cabut Akses'),
          ),
        ],
      ),
    );
  }
}
