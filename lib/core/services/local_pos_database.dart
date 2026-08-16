import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Durable local cache/queue for offline POS. The server remains authoritative;
/// this database only keeps enough state to survive network loss and app restarts.
class LocalPosDatabase {
  LocalPosDatabase._();
  static final instance = LocalPosDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(p.join(root, 'kasir_pos.db'), version: 1,
        onCreate: (db, _) async {
      await db.execute('''CREATE TABLE products_cache (
        id TEXT PRIMARY KEY, store_id TEXT NOT NULL, sku TEXT, name TEXT NOT NULL,
        selling_price INTEGER NOT NULL, cost_price INTEGER NOT NULL,
        stock INTEGER, is_active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE checkout_queue (
        idempotency_key TEXT PRIMARY KEY, store_id TEXT NOT NULL, shift_id TEXT NOT NULL,
        payload TEXT NOT NULL, created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT)''');
    });
    return _db!;
  }

  Future<void> cacheProducts(String storeId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('products_cache', {
        'id': r['id'], 'store_id': storeId, 'sku': r['sku'], 'name': r['name'],
        'selling_price': r['selling_price'] ?? 0, 'cost_price': r['cost_price'] ?? 0,
        'stock': r['stock'], 'is_active': (r['is_active'] ?? true) ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> products(String storeId, {String? query}) async {
    final db = await database;
    if (query == null || query.trim().isEmpty) {
      return db.query('products_cache', where: 'store_id = ? AND is_active = 1', whereArgs: [storeId], orderBy: 'name');
    }
    final q = '%${query.trim()}%';
    return db.query('products_cache', where: 'store_id = ? AND is_active = 1 AND (name LIKE ? OR sku LIKE ?)', whereArgs: [storeId, q, q], orderBy: 'name');
  }

  Future<void> enqueue({required String key, required String storeId, required String shiftId, required String payload}) async {
    final db = await database;
    await db.insert('checkout_queue', {
      'idempotency_key': key, 'store_id': storeId, 'shift_id': shiftId,
      'payload': payload, 'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> queue() async => (await database).query('checkout_queue', orderBy: 'created_at');
  Future<void> remove(String key) async => (await database).delete('checkout_queue', where: 'idempotency_key = ?', whereArgs: [key]);
  Future<void> fail(String key, String error) async => (await database).rawUpdate('UPDATE checkout_queue SET attempts = attempts + 1, last_error = ? WHERE idempotency_key = ?', [error, key]);
}
