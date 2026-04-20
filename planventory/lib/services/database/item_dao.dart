import '../../models/models.dart';
import 'database_service.dart';

/// Data Access Object for Item operations
class ItemDao {
  final DatabaseService _dbService = DatabaseService();

  /// Insert a new item
  Future<int> insert(Item item) async {
    final db = await _dbService.database;
    return await db.insert('items', item.toMap());
  }

  /// Update an existing item
  Future<int> update(Item item) async {
    final db = await _dbService.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Delete an item by ID
  Future<int> delete(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all items
  Future<List<Item>> getAll() async {
    final db = await _dbService.database;
    final maps = await db.query('items', orderBy: 'name ASC');
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  /// Get item by ID
  Future<Item?> getById(int id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  /// Get items by category
  Future<List<Item>> getByCategory(String category) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  /// Search items by name
  Future<List<Item>> search(String query) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'items',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  /// Get all unique categories
  Future<List<String>> getCategories() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM items WHERE category IS NOT NULL ORDER BY category',
    );
    return result.map((row) => row['category'] as String).toList();
  }

  /// Get items allocated to a specific event
  Future<List<Item>> getItemsForEvent(int eventId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT i.* FROM items i
      INNER JOIN allocations a ON i.id = a.item_id
      WHERE a.event_id = ?
      ORDER BY i.name ASC
    ''', [eventId]);
    return maps.map((map) => Item.fromMap(map)).toList();
  }
}
