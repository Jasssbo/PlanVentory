import '../../models/models.dart';
import 'database_service.dart';

/// Data Access Object for Allocation operations
class AllocationDao {
  final DatabaseService _dbService = DatabaseService();

  /// Insert a new allocation
  Future<int> insert(Allocation allocation) async {
    final db = await _dbService.database;
    return await db.insert('allocations', allocation.toMap());
  }

  /// Update an existing allocation
  Future<int> update(Allocation allocation) async {
    final db = await _dbService.database;
    return await db.update(
      'allocations',
      allocation.toMap(),
      where: 'id = ?',
      whereArgs: [allocation.id],
    );
  }

  /// Delete an allocation by ID
  Future<int> delete(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'allocations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all allocations for an event
  Future<List<Allocation>> getForEvent(int eventId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'allocations',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    return maps.map((map) => Allocation.fromMap(map)).toList();
  }

  /// Get all allocations for an item
  Future<List<Allocation>> getForItem(int itemId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'allocations',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return maps.map((map) => Allocation.fromMap(map)).toList();
  }

  /// Get allocation by event and item
  Future<Allocation?> getByEventAndItem(int eventId, int itemId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'allocations',
      where: 'event_id = ? AND item_id = ?',
      whereArgs: [eventId, itemId],
    );
    if (maps.isEmpty) return null;
    return Allocation.fromMap(maps.first);
  }

  /// Delete all allocations for an event
  Future<int> deleteForEvent(int eventId) async {
    final db = await _dbService.database;
    return await db.delete(
      'allocations',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  /// Delete all allocations for an item
  Future<int> deleteForItem(int itemId) async {
    final db = await _dbService.database;
    return await db.delete(
      'allocations',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  /// Get total quantity needed for an item within a date range
  /// Used to check for conflicts
  Future<int> getTotalNeededInDateRange(
      int itemId, DateTime start, DateTime end) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT SUM(a.quantity_needed) as total
      FROM allocations a
      INNER JOIN events e ON a.event_id = e.id
      WHERE a.item_id = ?
        AND e.start_date < ?
        AND e.end_date > ?
    ''', [itemId, end.toIso8601String(), start.toIso8601String()]);

    final total = result.first['total'];
    return (total as int?) ?? 0;
  }
}
