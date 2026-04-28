import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../config/config.dart';

/// Main database service for SQLite operations
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _isInitialized = false;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Initialize the database factory for the current platform
  static Future<void> initializeDatabaseFactory() async {
    if (_isInitialized) return;

    // Use FFI for desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      AppLogger.info('Using sqflite_ffi for desktop', tag: 'Database');
    } else {
      AppLogger.info('Using native sqflite', tag: 'Database');
    }

    _isInitialized = true;
  }

  /// Get database instance, creating if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'planventory.db');

    return await openDatabase(
      path,
      version: 8,  // Added per-item rental cost
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Items table
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        category TEXT,
        image_url TEXT,
        is_rental_only INTEGER NOT NULL DEFAULT 0,
        unit_cost REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Events table
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        location TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'upcoming',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Allocations table (junction table)
    await db.execute('''
      CREATE TABLE allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity_needed INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        venue_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE,
        FOREIGN KEY (venue_id) REFERENCES venues (id) ON DELETE SET NULL
      )
    ''');

    // Indexes for faster queries
    await db.execute(
        'CREATE INDEX idx_allocations_event ON allocations(event_id)');
    await db.execute(
        'CREATE INDEX idx_allocations_item ON allocations(item_id)');
    await db.execute(
        'CREATE INDEX idx_events_dates ON events(start_date, end_date)');

    // Rentals table - for tracking external rentals (multi-item support)
    await db.execute('''
      CREATE TABLE rentals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        company_name TEXT NOT NULL,
        company_contact TEXT,
        rental_cost REAL,
        currency TEXT DEFAULT 'EUR',
        pickup_date TEXT NOT NULL,
        pickup_location TEXT,
        pickup_notes TEXT,
        return_date TEXT NOT NULL,
        return_location TEXT,
        return_notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        actual_pickup_date TEXT,
        actual_return_date TEXT,
        return_confirmation TEXT,
        venue_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
      )
    ''');
    
    // Rental items table - items within a rental
    await db.execute('''
      CREATE TABLE rental_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rental_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        item_cost REAL,
        FOREIGN KEY (rental_id) REFERENCES rentals (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');

    // Venues table
    await db.execute('''
      CREATE TABLE venues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_venues_event ON venues(event_id)');
    await db.execute(
        'CREATE INDEX idx_rentals_event ON rentals(event_id)');
    await db.execute(
        'CREATE INDEX idx_rentals_status ON rentals(status)');
    await db.execute(
        'CREATE INDEX idx_rentals_dates ON rentals(pickup_date, return_date)');
    await db.execute(
        'CREATE INDEX idx_rental_items_rental ON rental_items(rental_id)');
    await db.execute(
        'CREATE INDEX idx_rental_items_item ON rental_items(item_id)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration from version 1 to 2: Add rentals table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rentals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_id INTEGER NOT NULL,
          item_id INTEGER NOT NULL,
          quantity_rented INTEGER NOT NULL DEFAULT 1,
          company_name TEXT NOT NULL,
          company_contact TEXT,
          rental_cost REAL,
          currency TEXT DEFAULT 'EUR',
          pickup_date TEXT NOT NULL,
          pickup_location TEXT,
          pickup_notes TEXT,
          return_date TEXT NOT NULL,
          return_location TEXT,
          return_notes TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          actual_pickup_date TEXT,
          actual_return_date TEXT,
          return_confirmation TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE,
          FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rentals_event ON rentals(event_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rentals_item ON rentals(item_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rentals_dates ON rentals(pickup_date, return_date)');
    }
    
    // Migration from version 2 to 3: Multi-item rentals
    if (oldVersion < 3) {
      // Create rental_items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rental_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rental_id INTEGER NOT NULL,
          item_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (rental_id) REFERENCES rentals (id) ON DELETE CASCADE,
          FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rental_items_rental ON rental_items(rental_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rental_items_item ON rental_items(item_id)');
      
      // Migrate existing rental data to rental_items
      final existingRentals = await db.query('rentals', 
          columns: ['id', 'item_id', 'quantity_rented']);
      
      for (final rental in existingRentals) {
        final rentalId = rental['id'] as int;
        final itemId = rental['item_id'];
        final quantity = rental['quantity_rented'] ?? 1;
        
        if (itemId != null) {
          await db.insert('rental_items', {
            'rental_id': rentalId,
            'item_id': itemId,
            'quantity': quantity,
          });
        }
      }
      
      // SQLite doesn't support DROP COLUMN, so recreate the table without item_id NOT NULL
      await db.execute('''
        CREATE TABLE rentals_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_id INTEGER NOT NULL,
          company_name TEXT NOT NULL,
          company_contact TEXT,
          rental_cost REAL,
          currency TEXT DEFAULT 'EUR',
          pickup_date TEXT NOT NULL,
          pickup_location TEXT,
          pickup_notes TEXT,
          return_date TEXT NOT NULL,
          return_location TEXT,
          return_notes TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          actual_pickup_date TEXT,
          actual_return_date TEXT,
          return_confirmation TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
        )
      ''');
      
      // Copy data (excluding item_id and quantity_rented)
      await db.execute('''
        INSERT INTO rentals_new (id, event_id, company_name, company_contact, rental_cost, 
          currency, pickup_date, pickup_location, pickup_notes, return_date, return_location,
          return_notes, status, actual_pickup_date, actual_return_date, return_confirmation,
          created_at, updated_at)
        SELECT id, event_id, company_name, company_contact, rental_cost, 
          currency, pickup_date, pickup_location, pickup_notes, return_date, return_location,
          return_notes, status, actual_pickup_date, actual_return_date, return_confirmation,
          created_at, updated_at
        FROM rentals
      ''');
      
      // Drop old table and rename new one
      await db.execute('DROP TABLE rentals');
      await db.execute('ALTER TABLE rentals_new RENAME TO rentals');
      
      // Recreate indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_event ON rentals(event_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_dates ON rentals(pickup_date, return_date)');
    }
    
    // Migration from version 3 to 4: Fix rentals table that still has item_id NOT NULL
    if (oldVersion == 3) {
      // Check if rentals table still has item_id column (broken v3 migration)
      final tableInfo = await db.rawQuery("PRAGMA table_info(rentals)");
      final hasItemId = tableInfo.any((col) => col['name'] == 'item_id');
      
      if (hasItemId) {
        // Need to recreate the table without item_id
        await db.execute('''
          CREATE TABLE rentals_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL,
            company_name TEXT NOT NULL,
            company_contact TEXT,
            rental_cost REAL,
            currency TEXT DEFAULT 'EUR',
            pickup_date TEXT NOT NULL,
            pickup_location TEXT,
            pickup_notes TEXT,
            return_date TEXT NOT NULL,
            return_location TEXT,
            return_notes TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            actual_pickup_date TEXT,
            actual_return_date TEXT,
            return_confirmation TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
          )
        ''');
        
        // Copy data (excluding item_id and quantity_rented)
        await db.execute('''
          INSERT INTO rentals_new (id, event_id, company_name, company_contact, rental_cost, 
            currency, pickup_date, pickup_location, pickup_notes, return_date, return_location,
            return_notes, status, actual_pickup_date, actual_return_date, return_confirmation,
            created_at, updated_at)
          SELECT id, event_id, company_name, company_contact, rental_cost, 
            currency, pickup_date, pickup_location, pickup_notes, return_date, return_location,
            return_notes, status, actual_pickup_date, actual_return_date, return_confirmation,
            created_at, updated_at
          FROM rentals
        ''');
        
        // Drop old table and rename new one
        await db.execute('DROP TABLE rentals');
        await db.execute('ALTER TABLE rentals_new RENAME TO rentals');
        
        // Recreate indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_event ON rentals(event_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rentals_dates ON rentals(pickup_date, return_date)');
      }
    }
    
    // Migration from version 4 to 5: Add rental-only items support
    if (oldVersion < 5) {
      // Add is_rental_only column to items table
      await db.execute('ALTER TABLE items ADD COLUMN is_rental_only INTEGER NOT NULL DEFAULT 0');
    }

    // Migration from version 5 to 6: Add unit cost per inventory item
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE items ADD COLUMN unit_cost REAL');
    }

    // Migration from version 6 to 7: Add venues/stages
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS venues (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_venues_event ON venues(event_id)');
      await db.execute('ALTER TABLE allocations ADD COLUMN venue_id INTEGER');
      await db.execute('ALTER TABLE rentals ADD COLUMN venue_id INTEGER');
    }

    // Migration from version 7 to 8: Per-item rental cost
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE rental_items ADD COLUMN item_cost REAL');
    }
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
