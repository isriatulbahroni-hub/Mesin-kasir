import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import 'providers/customers_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => context.push('/customers/new')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari nama/nomor HP/kode member...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald600)),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers.where((c) =>
                        c.name.toLowerCase().contains(_query) ||
                        (c.phone?.toLowerCase().contains(_query) ?? false) ||
                        (c.memberCode?.toLowerCase().contains(_query) ?? false)).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Belum ada pelanggan. Tambahkan lewat tombol +'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _CustomerTile(customer: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/customers/${customer.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.emerald100,
          child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.emerald700, fontWeight: FontWeight.w700)),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [if (customer.phone != null) customer.phone!, '${customer.points} poin'].join(' · '),
          style: const TextStyle(color: AppColors.charcoal500, fontSize: 12.5),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
