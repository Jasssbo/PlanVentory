import '../../models/models.dart';
import 'database_service.dart';

/// Data Access Object for Event operations
class EventDao {
  final DatabaseService _dbService = DatabaseService();

  /// Insert a new event
  Future<int> insert(Event event) async {
    final db = await _dbService.database;
    return await db.insert('events', event.toMap());
  }

  /// Update an existing event
  Future<int> update(Event event) async {
    final db = await _dbService.database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// Delete an event by ID
  Future<int> delete(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all events
  Future<List<Event>> getAll() async {
    final db = await _dbService.database;
    final maps = await db.query('events', orderBy: 'start_date ASC');
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  /// Get event by ID
  Future<Event?> getById(int id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  /// Get upcoming events
  Future<List<Event>> getUpcoming() async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'events',
      where: 'end_date >= ?',
      whereArgs: [now],
      orderBy: 'start_date ASC',
    );
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  /// Get past events
  Future<List<Event>> getPast() async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'events',
      where: 'end_date < ?',
      whereArgs: [now],
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  /// Get events in a date range
  Future<List<Event>> getInDateRange(DateTime start, DateTime end) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'events',
      where: 'start_date <= ? AND end_date >= ?',
      whereArgs: [end.toIso8601String(), start.toIso8601String()],
      orderBy: 'start_date ASC',
    );
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  /// Get events that overlap with a given date range
  /// Used to detect conflicts
  Future<List<Event>> getOverlapping(DateTime start, DateTime end,
      {int? excludeEventId}) async {
    final db = await _dbService.database;
    String where = 'start_date < ? AND end_date > ?';
    List<dynamic> whereArgs = [end.toIso8601String(), start.toIso8601String()];

    if (excludeEventId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeEventId);
    }

    final maps = await db.query(
      'events',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_date ASC',
    );
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  /// Get events that use a specific item
  Future<List<Event>> getEventsUsingItem(int itemId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT e.* FROM events e
      INNER JOIN allocations a ON e.id = a.event_id
      WHERE a.item_id = ?
      ORDER BY e.start_date ASC
    ''', [itemId]);
    return maps.map((map) => Event.fromMap(map)).toList();
  }
}
