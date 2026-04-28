import '../../models/models.dart';
import 'database_service.dart';

/// Data Access Object for Rental operations (with multi-item support)
class RentalDao {
  final DatabaseService _dbService = DatabaseService();

  /// Insert a new rental with its items
  Future<int> insert(Rental rental) async {
    final db = await _dbService.database;
    
    // Insert the rental first
    final rentalId = await db.insert('rentals', rental.toMap());
    
    // Insert all rental items
    for (final item in rental.items) {
      await db.insert('rental_items', {
        'rental_id': rentalId,
        'item_id': item.itemId,
        'quantity': item.quantity,
        'item_cost': item.itemCost,
      });
    }
    
    return rentalId;
  }

  /// Update an existing rental (items are replaced)
  Future<int> update(Rental rental) async {
    final db = await _dbService.database;
    
    // Update the rental
    final result = await db.update(
      'rentals',
      rental.toMap(),
      where: 'id = ?',
      whereArgs: [rental.id],
    );
    
    // Delete existing items and re-insert
    await db.delete('rental_items', where: 'rental_id = ?', whereArgs: [rental.id]);
    
    for (final item in rental.items) {
      await db.insert('rental_items', {
        'rental_id': rental.id,
        'item_id': item.itemId,
        'quantity': item.quantity,
        'item_cost': item.itemCost,
      });
    }
    
    return result;
  }

  /// Delete a rental by ID (items are deleted via CASCADE)
  Future<int> delete(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'rentals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Load rental items for a rental, with item names
  Future<List<RentalItem>> _loadRentalItems(int rentalId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT ri.*, i.name as item_name 
      FROM rental_items ri
      LEFT JOIN items i ON ri.item_id = i.id
      WHERE ri.rental_id = ?
    ''', [rentalId]);
    
    return maps.map((map) => RentalItem.fromMap(map)).toList();
  }

  /// Get all rentals with their items
  Future<List<Rental>> getAll() async {
    final db = await _dbService.database;
    final maps = await db.query('rentals', orderBy: 'pickup_date ASC');
    
    final rentals = <Rental>[];
    for (final map in maps) {
      final items = await _loadRentalItems(map['id'] as int);
      rentals.add(Rental.fromMap(map, items: items));
    }
    return rentals;
  }

  /// Get a rental by ID with its items
  Future<Rental?> getById(int id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'rentals',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    final items = await _loadRentalItems(id);
    return Rental.fromMap(maps.first, items: items);
  }

  /// Get all rentals for an event with their items
  Future<List<Rental>> getForEvent(int eventId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'rentals',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'pickup_date ASC',
    );
    
    final rentals = <Rental>[];
    for (final map in maps) {
      final items = await _loadRentalItems(map['id'] as int);
      rentals.add(Rental.fromMap(map, items: items));
    }
    return rentals;
  }

  /// Get all rentals containing a specific item
  Future<List<Rental>> getForItem(int itemId) async {
    final db = await _dbService.database;
    final rentalIds = await db.rawQuery('''
      SELECT DISTINCT rental_id FROM rental_items WHERE item_id = ?
    ''', [itemId]);
    
    final rentals = <Rental>[];
    for (final row in rentalIds) {
      final rental = await getById(row['rental_id'] as int);
      if (rental != null) rentals.add(rental);
    }
    return rentals;
  }

  /// Get pending rentals (not yet picked up) with their items
  Future<List<Rental>> getPending() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'rentals',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'pickup_date ASC',
    );
    
    final rentals = <Rental>[];
    for (final map in maps) {
      final items = await _loadRentalItems(map['id'] as int);
      rentals.add(Rental.fromMap(map, items: items));
    }
    return rentals;
  }

  /// Get active rentals (picked up but not returned) with their items
  Future<List<Rental>> getActive() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'rentals',
      where: 'status = ?',
      whereArgs: ['pickedUp'],
      orderBy: 'return_date ASC',
    );
    
    final rentals = <Rental>[];
    for (final map in maps) {
      final items = await _loadRentalItems(map['id'] as int);
      rentals.add(Rental.fromMap(map, items: items));
    }
    return rentals;
  }

  /// Get overdue rentals with their items
  Future<List<Rental>> getOverdue() async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'rentals',
      where: 'status = ? AND return_date < ?',
      whereArgs: ['pickedUp', now],
      orderBy: 'return_date ASC',
    );
    
    final rentals = <Rental>[];
    for (final map in maps) {
      final items = await _loadRentalItems(map['id'] as int);
      rentals.add(Rental.fromMap(map, items: items));
    }
    return rentals;
  }

  /// Mark a rental as picked up
  Future<int> markPickedUp(int id, {String? notes}) async {
    final db = await _dbService.database;
    return await db.update(
      'rentals',
      {
        'status': 'pickedUp',
        'actual_pickup_date': DateTime.now().toIso8601String(),
        'pickup_notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark a rental as returned
  Future<int> markReturned(int id, {String? confirmation}) async {
    final db = await _dbService.database;
    return await db.update(
      'rentals',
      {
        'status': 'returned',
        'actual_return_date': DateTime.now().toIso8601String(),
        'return_confirmation': confirmation,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cancel a rental
  Future<int> cancel(int id) async {
    final db = await _dbService.database;
    return await db.update(
      'rentals',
      {
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all rentals for an event (items deleted via CASCADE)
  Future<int> deleteForEvent(int eventId) async {
    final db = await _dbService.database;
    return await db.delete(
      'rentals',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  /// Get total quantity rented for an item in a date range
  /// Used for availability calculations
  Future<int> getTotalRentedInDateRange(
    int itemId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(ri.quantity), 0) as total
      FROM rental_items ri
      INNER JOIN rentals r ON ri.rental_id = r.id
      WHERE ri.item_id = ?
        AND r.status IN ('pending', 'pickedUp')
        AND r.pickup_date < ?
        AND r.return_date > ?
    ''', [itemId, end.toIso8601String(), start.toIso8601String()]);

    return (result.first['total'] as int?) ?? 0;
  }
}
