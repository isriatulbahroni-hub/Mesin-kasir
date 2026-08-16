import 'package:flutter/material.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/providers/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineSyncScreen extends ConsumerStatefulWidget {
  const OfflineSyncScreen({super.key});
  @override
  ConsumerState<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends ConsumerState<OfflineSyncScreen> {
  late final OfflineSyncService _sync;
  int _pending = 0;
  bool _loading = true;
  String? _message;

  @override
  void initState() { super.initState(); _sync = OfflineSyncService(ref.read(supabaseClientProvider)); _refresh(); }

  Future<void> _refresh() async {
    final n = await _sync.pendingCount();
    if (mounted) setState(() { _pending = n; _loading = false; });
  }

  Future<void> _syncNow() async {
    setState(() { _loading = true; _message = null; });
    final errors = await _sync.syncPending();
    await _refresh();
    if (mounted) setState(() => _message = errors.isEmpty ? 'Semua transaksi offline berhasil disinkronkan.' : '${errors.length} transaksi masih menunggu koneksi/validasi.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline & Sinkronisasi')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: ListTile(leading: const Icon(Icons.cloud_off), title: const Text('Transaksi menunggu sinkronisasi'), trailing: Text('$_pending', style: Theme.of(context).textTheme.headlineSmall))),
      const SizedBox(height: 12),
      const Text('Katalog produk terakhir disimpan di perangkat. Jika koneksi terputus saat checkout, transaksi masuk antrean lokal dan tidak dianggap selesai di server sampai berhasil disinkronkan.'),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _loading ? null : _syncNow, icon: const Icon(Icons.sync), label: Text(_loading ? 'Memeriksa...' : 'Sinkronkan sekarang')),
      if (_message != null) ...[const SizedBox(height: 16), Text(_message!)],
    ]),
  );
}
