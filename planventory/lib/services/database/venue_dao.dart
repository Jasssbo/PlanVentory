import '../../models/models.dart';
import 'database_service.dart';

/// Data Access Object for Venue operations
class VenueDao {
  final DatabaseService _dbService = DatabaseService();

  Future<int> insert(Venue venue) async {
    final db = await _dbService.database;
    return await db.insert('venues', venue.toMap());
  }

  Future<int> update(Venue venue) async {
    final db = await _dbService.database;
    return await db.update(
      'venues',
      venue.toMap(),
      where: 'id = ?',
      whereArgs: [venue.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbService.database;
    return await db.delete('venues', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Venue>> getForEvent(int eventId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'venues',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map((m) => Venue.fromMap(m)).toList();
  }

  Future<Venue?> getById(int id) async {
    final db = await _dbService.database;
    final maps = await db.query('venues', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Venue.fromMap(maps.first);
  }

  /// Unassign all allocations and rentals belonging to this venue
  /// (sets venue_id to NULL rather than deleting them).
  Future<void> unassignItemsForVenue(int venueId) async {
    final db = await _dbService.database;
    await db.update(
      'allocations',
      {'venue_id': null},
      where: 'venue_id = ?',
      whereArgs: [venueId],
    );
    await db.update(
      'rentals',
      {'venue_id': null},
      where: 'venue_id = ?',
      whereArgs: [venueId],
    );
  }
}
