import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../models/transaction.dart';
import '../../../models/transaction_item.dart';

class KitchenOrder {
  final Transaction transaction;
  final List<TransactionItem> items;
  KitchenOrder({required this.transaction, required this.items});

  bool get isAllServed => items.every((i) => i.kitchenStatus == 'served');
}

/// Pesanan aktif untuk Kitchen Display: transaksi hari ini yang statusnya
/// completed dan MASIH ada item yang belum 'served'. Realtime lewat stream
/// transaction_items, digabung dengan header transaksi.
final kitchenOrdersProvider = StreamProvider.autoDispose<List<KitchenOrder>>((ref) async* {
  final staff = await ref.watch(currentStaffProvider.future);
  if (staff == null) {
    yield [];
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  final startOfDay = DateTime.now();
  final todayStart = DateTime(startOfDay.year, startOfDay.month, startOfDay.day).toUtc();

  final stream = client.from('transaction_items').stream(primaryKey: ['id']);

  await for (final _ in stream) {
    // Stream transaction_items dipakai sebagai trigger refetch — data
    // sebenarnya diambil gabungan (join manual) supaya dapat invoice_no dsb.
    final txRows = await client
        .from('transactions')
        .select()
        .eq('store_id', staff.storeId)
        .eq('status', 'completed')
        .gte('created_at', todayStart.toIso8601String())
        .order('created_at');

    final transactions = (txRows as List).map((e) => Transaction.fromJson(e)).toList();
    if (transactions.isEmpty) {
      yield [];
      continue;
    }

    final txIds = transactions.map((t) => t.id).toList();
    final itemRows = await client
        .from('transaction_items')
        .select()
        .inFilter('transaction_id', txIds)
        .order('id');
    final allItems = (itemRows as List).map((e) => TransactionItem.fromJson(e)).toList();

    final orders = <KitchenOrder>[];
    for (final tx in transactions) {
      final items = allItems.where((i) => i.transactionId == tx.id).toList();
      if (items.isEmpty) continue;
      if (items.every((i) => i.kitchenStatus == 'served')) continue; // sudah kelar, gak usah ditampilin
      orders.add(KitchenOrder(transaction: tx, items: items));
    }

    yield orders;
  }
});

class KitchenController {
  KitchenController(this._ref);
  final Ref _ref;

  Future<String?> updateStatus(String transactionItemId, String status) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.rpc('update_kitchen_status', params: {
        'p_transaction_item_id': transactionItemId,
        'p_status': status,
      });
      return null;
    } on Object catch (e) {
      return 'Gagal update status: $e';
    }
  }
}

final kitchenControllerProvider = Provider((ref) => KitchenController(ref));
