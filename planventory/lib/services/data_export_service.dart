import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import 'database/item_dao.dart';
import 'database/event_dao.dart';
import 'database/allocation_dao.dart';
import 'database/rental_dao.dart';

/// Data type options for export/import
enum DataExportType {
  inventory,
  events,
  both;

  String get displayName {
    switch (this) {
      case DataExportType.inventory:
        return 'Inventory Only';
      case DataExportType.events:
        return 'Events Only';
      case DataExportType.both:
        return 'All Data';
    }
  }

  String get description {
    switch (this) {
      case DataExportType.inventory:
        return 'Items and categories';
      case DataExportType.events:
        return 'Events, allocations, and rentals';
      case DataExportType.both:
        return 'Complete database backup';
    }
  }
}

/// Result of an export/import operation
class DataOperationResult {
  final bool success;
  final String message;
  final String? filePath;

  DataOperationResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Service for exporting and importing app data as JSON
class DataExportService {
  final ItemDao _itemDao = ItemDao();
  final EventDao _eventDao = EventDao();
  final AllocationDao _allocationDao = AllocationDao();
  final RentalDao _rentalDao = RentalDao();

  static const String _exportVersion = '1.0';
  static const String _appIdentifier = 'planventory';

  /// Export data to a JSON file in the Downloads folder
  Future<DataOperationResult> exportData(DataExportType type) async {
    try {
      final exportData = await _buildExportData(type);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final typeSuffix = type.name;
      final filename = 'planventory_${typeSuffix}_$timestamp.json';
      
      // Get Downloads directory
      final directory = await _getDownloadsDirectory();
      if (directory == null) {
        return DataOperationResult(
          success: false,
          message: 'Could not access Downloads folder',
        );
      }
      
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(jsonString);
      
      return DataOperationResult(
        success: true,
        message: 'Data exported successfully',
        filePath: filePath,
      );
    } catch (e) {
      return DataOperationResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  /// Export and share data via system share dialog
  Future<DataOperationResult> exportAndShare(DataExportType type) async {
    try {
      final exportData = await _buildExportData(type);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final typeSuffix = type.name;
      final filename = 'planventory_${typeSuffix}_$timestamp.json';
      
      // Create temp file for sharing
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(jsonString);
      
      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'PlanVentory ${type.displayName} Export',
        ),
      );
      
      return DataOperationResult(
        success: true,
        message: 'Share dialog opened',
        filePath: filePath,
      );
    } catch (e) {
      return DataOperationResult(
        success: false,
        message: 'Share failed: $e',
      );
    }
  }

  /// Import data from a JSON file
  Future<DataOperationResult> importData() async {
    try {
      // Pick a JSON file
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        return DataOperationResult(
          success: false,
          message: 'No file selected',
        );
      }
      
      final filePath = result.files.single.path;
      if (filePath == null) {
        return DataOperationResult(
          success: false,
          message: 'Could not access file',
        );
      }
      
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate file format
      if (data['app'] != _appIdentifier) {
        return DataOperationResult(
          success: false,
          message: 'Invalid file format: not a PlanVentory export file',
        );
      }
      
      // Import the data
      final importResult = await _importFromData(data);
      return importResult;
    } catch (e) {
      return DataOperationResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  /// Build export data structure
  Future<Map<String, dynamic>> _buildExportData(DataExportType type) async {
    final data = <String, dynamic>{
      'app': _appIdentifier,
      'version': _exportVersion,
      'exportType': type.name,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    
    if (type == DataExportType.inventory || type == DataExportType.both) {
      final items = await _itemDao.getAll();
      data['items'] = items.map((item) => _itemToJson(item)).toList();
    }
    
    if (type == DataExportType.events || type == DataExportType.both) {
      final events = await _eventDao.getAll();
      final allocations = <Map<String, dynamic>>[];
      final rentals = <Map<String, dynamic>>[];
      
      for (final event in events) {
        final eventAllocations = await _allocationDao.getForEvent(event.id!);
        for (final allocation in eventAllocations) {
          allocations.add(_allocationToJson(allocation));
        }
        
        final eventRentals = await _rentalDao.getForEvent(event.id!);
        for (final rental in eventRentals) {
          rentals.add(_rentalToJson(rental));
        }
      }
      
      data['events'] = events.map((event) => _eventToJson(event)).toList();
      data['allocations'] = allocations;
      data['rentals'] = rentals;
    }
    
    return data;
  }

  /// Import data from parsed JSON
  Future<DataOperationResult> _importFromData(Map<String, dynamic> data) async {
    int itemsImported = 0;
    int eventsImported = 0;
    int allocationsImported = 0;
    int rentalsImported = 0;
    
    // Map old IDs to new IDs for relationships
    final itemIdMap = <int, int>{};
    final eventIdMap = <int, int>{};
    
    try {
      // Import items
      if (data['items'] != null) {
        final itemsList = data['items'] as List;
        for (final itemJson in itemsList) {
          final item = _itemFromJson(itemJson as Map<String, dynamic>);
          final oldId = itemJson['id'] as int?;
          final newId = await _itemDao.insert(item);
          if (oldId != null) {
            itemIdMap[oldId] = newId;
          }
          itemsImported++;
        }
      }
      
      // Import events
      if (data['events'] != null) {
        final eventsList = data['events'] as List;
        for (final eventJson in eventsList) {
          final event = _eventFromJson(eventJson as Map<String, dynamic>);
          final oldId = eventJson['id'] as int?;
          final newId = await _eventDao.insert(event);
          if (oldId != null) {
            eventIdMap[oldId] = newId;
          }
          eventsImported++;
        }
      }
      
      // Import allocations (with updated IDs)
      if (data['allocations'] != null) {
        final allocationsList = data['allocations'] as List;
        for (final allocJson in allocationsList) {
          final oldEventId = allocJson['eventId'] as int;
          final oldItemId = allocJson['itemId'] as int;
          
          // Only import if both event and item exist
          final newEventId = eventIdMap[oldEventId];
          final newItemId = itemIdMap[oldItemId];
          
          if (newEventId != null && newItemId != null) {
            final allocation = Allocation(
              eventId: newEventId,
              itemId: newItemId,
              quantityNeeded: allocJson['quantityNeeded'] as int? ?? 1,
              notes: allocJson['notes'] as String?,
            );
            await _allocationDao.insert(allocation);
            allocationsImported++;
          }
        }
      }
      
      // Import rentals (with updated event IDs)
      if (data['rentals'] != null) {
        final rentalsList = data['rentals'] as List;
        for (final rentalJson in rentalsList) {
          final oldEventId = rentalJson['eventId'] as int;
          final newEventId = eventIdMap[oldEventId];
          
          if (newEventId != null) {
            final rental = _rentalFromJson(rentalJson as Map<String, dynamic>, newEventId, itemIdMap);
            await _rentalDao.insert(rental);
            rentalsImported++;
          }
        }
      }
      
      final summaryParts = <String>[];
      if (itemsImported > 0) summaryParts.add('$itemsImported items');
      if (eventsImported > 0) summaryParts.add('$eventsImported events');
      if (allocationsImported > 0) summaryParts.add('$allocationsImported allocations');
      if (rentalsImported > 0) summaryParts.add('$rentalsImported rentals');
      
      final summary = summaryParts.isEmpty 
          ? 'No data imported' 
          : 'Imported: ${summaryParts.join(', ')}';
      
      return DataOperationResult(
        success: true,
        message: summary,
      );
    } catch (e) {
      return DataOperationResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  /// Get the Downloads directory (cross-platform)
  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // On Android, use the external storage Downloads directory
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // On iOS, use the documents directory (no direct Downloads access)
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // On desktop, try to get Downloads directory
      final downloadsDir = await getDownloadsDirectory();
      return downloadsDir ?? await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  // ============ JSON Conversion Helpers ============

  Map<String, dynamic> _itemToJson(Item item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'quantity': item.quantity,
      'category': item.category,
      'imageUrl': item.imageUrl,
      'isRentalOnly': item.isRentalOnly,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  Item _itemFromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      description: json['description'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isRentalOnly: json['isRentalOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _eventToJson(Event event) {
    return {
      'id': event.id,
      'name': event.name,
      'description': event.description,
      'location': event.location,
      'startDate': event.startDate.toIso8601String(),
      'endDate': event.endDate.toIso8601String(),
      'status': event.status,
      'notes': event.notes,
      'createdAt': event.createdAt.toIso8601String(),
      'updatedAt': event.updatedAt.toIso8601String(),
    };
  }

  Event _eventFromJson(Map<String, dynamic> json) {
    return Event(
      name: json['name'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: json['status'] as String? ?? 'upcoming',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> _allocationToJson(Allocation allocation) {
    return {
      'eventId': allocation.eventId,
      'itemId': allocation.itemId,
      'quantityNeeded': allocation.quantityNeeded,
      'notes': allocation.notes,
    };
  }

  Map<String, dynamic> _rentalToJson(Rental rental) {
    return {
      'eventId': rental.eventId,
      'companyName': rental.companyName,
      'companyContact': rental.companyContact,
      'rentalCost': rental.rentalCost,
      'currency': rental.currency,
      'pickupDate': rental.pickupDate.toIso8601String(),
      'pickupLocation': rental.pickupLocation,
      'pickupNotes': rental.pickupNotes,
      'returnDate': rental.returnDate.toIso8601String(),
      'returnLocation': rental.returnLocation,
      'returnNotes': rental.returnNotes,
      'status': rental.status.name,
      'items': rental.items.map((item) => {
        'itemId': item.itemId,
        'quantity': item.quantity,
        'itemName': item.itemName,
      }).toList(),
    };
  }

  Rental _rentalFromJson(Map<String, dynamic> json, int newEventId, Map<int, int> itemIdMap) {
    final itemsList = (json['items'] as List?) ?? [];
    final items = itemsList.map((itemJson) {
      final oldItemId = itemJson['itemId'] as int;
      final newItemId = itemIdMap[oldItemId] ?? oldItemId;
      return RentalItem(
        rentalId: 0, // Will be set by DAO
        itemId: newItemId,
        quantity: itemJson['quantity'] as int? ?? 1,
        itemName: itemJson['itemName'] as String?,
      );
    }).toList();
    
    return Rental(
      eventId: newEventId,
      items: items,
      companyName: json['companyName'] as String,
      companyContact: json['companyContact'] as String?,
      rentalCost: (json['rentalCost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      pickupDate: DateTime.parse(json['pickupDate'] as String),
      pickupLocation: json['pickupLocation'] as String?,
      pickupNotes: json['pickupNotes'] as String?,
      returnDate: DateTime.parse(json['returnDate'] as String),
      returnLocation: json['returnLocation'] as String?,
      returnNotes: json['returnNotes'] as String?,
      status: RentalStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RentalStatus.pending,
      ),
    );
  }
}
