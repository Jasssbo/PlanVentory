import '../models/models.dart';
import 'database/allocation_dao.dart';
import 'database/item_dao.dart';
import 'database/event_dao.dart';
import 'database/rental_dao.dart';

/// Service for checking material availability and conflicts
class AvailabilityService {
  final ItemDao _itemDao = ItemDao();
  final EventDao _eventDao = EventDao();
  final AllocationDao _allocationDao = AllocationDao();
  final RentalDao _rentalDao = RentalDao();

  /// Check availability of an item for a specific event
  /// Returns AvailabilityResult with details about what's available
  Future<AvailabilityResult> checkAvailability({
    required int itemId,
    required DateTime startDate,
    required DateTime endDate,
    int? excludeEventId,  // Exclude current event when editing
  }) async {
    // Get the item
    final item = await _itemDao.getById(itemId);
    if (item == null) {
      return AvailabilityResult(
        itemId: itemId,
        itemName: 'Unknown',
        totalOwned: 0,
        alreadyAllocated: 0,
        rentedQuantity: 0,
        available: 0,
        isAvailable: false,
        conflicts: [],
      );
    }

    // Get all events that overlap with the date range
    final overlappingEvents = await _eventDao.getInDateRange(startDate, endDate);
    
    // Calculate total allocated to other events in this period
    int totalAllocated = 0;
    final conflicts = <AllocationConflict>[];

    for (final event in overlappingEvents) {
      if (event.id == excludeEventId) continue;  // Skip the event we're editing
      
      final allocations = await _allocationDao.getForEvent(event.id!);
      for (final allocation in allocations) {
        if (allocation.itemId == itemId) {
          totalAllocated += allocation.quantityNeeded;
          conflicts.add(AllocationConflict(
            eventId: event.id!,
            eventName: event.name,
            eventStart: event.startDate,
            eventEnd: event.endDate,
            quantityUsed: allocation.quantityNeeded,
          ));
        }
      }
    }

    // Get active rentals for this item (those provide extra availability)
    final rentedQuantity = await _rentalDao.getTotalRentedInDateRange(
      itemId,
      startDate,
      endDate,
    );

    final available = item.quantity - totalAllocated;

    return AvailabilityResult(
      itemId: itemId,
      itemName: item.name,
      totalOwned: item.quantity,
      alreadyAllocated: totalAllocated,
      rentedQuantity: rentedQuantity,
      available: available,
      isAvailable: available > 0,
      conflicts: conflicts,
    );
  }

  /// Check availability for multiple items at once
  Future<List<AvailabilityResult>> checkMultipleAvailability({
    required List<int> itemIds,
    required DateTime startDate,
    required DateTime endDate,
    int? excludeEventId,
  }) async {
    final results = <AvailabilityResult>[];
    for (final itemId in itemIds) {
      final result = await checkAvailability(
        itemId: itemId,
        startDate: startDate,
        endDate: endDate,
        excludeEventId: excludeEventId,
      );
      results.add(result);
    }
    return results;
  }

  /// Get shortage details - how many items are missing for an event
  Future<List<ShortageInfo>> getShortagesForEvent({
    required int eventId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allocations = await _allocationDao.getForEvent(eventId);
    final shortages = <ShortageInfo>[];

    for (final allocation in allocations) {
      final availability = await checkAvailability(
        itemId: allocation.itemId,
        startDate: startDate,
        endDate: endDate,
        excludeEventId: eventId,
      );

      final shortage = allocation.quantityNeeded - (availability.available + availability.rentedQuantity);
      if (shortage > 0) {
        shortages.add(ShortageInfo(
          itemId: allocation.itemId,
          itemName: availability.itemName,
          quantityNeeded: allocation.quantityNeeded,
          quantityAvailable: availability.available,
          quantityRented: availability.rentedQuantity,
          shortage: shortage,
          conflicts: availability.conflicts,
        ));
      }
    }

    return shortages;
  }

  /// Get all items with their availability for an event
  Future<List<ItemWithAvailability>> getItemsWithAvailability({
    required DateTime startDate,
    required DateTime endDate,
    int? excludeEventId,
  }) async {
    final items = await _itemDao.getAll();
    final itemsWithAvailability = <ItemWithAvailability>[];

    for (final item in items) {
      final availability = await checkAvailability(
        itemId: item.id!,
        startDate: startDate,
        endDate: endDate,
        excludeEventId: excludeEventId,
      );
      
      itemsWithAvailability.add(ItemWithAvailability(
        item: item,
        availability: availability,
      ));
    }

    return itemsWithAvailability;
  }
}

/// Result of availability check for an item
class AvailabilityResult {
  final int itemId;
  final String itemName;
  final int totalOwned;       // Total in inventory
  final int alreadyAllocated; // Already assigned to other overlapping events
  final int rentedQuantity;   // Currently rented from other companies
  final int available;        // Free to use
  final bool isAvailable;     // Is there at least one available
  final List<AllocationConflict> conflicts;  // Events using this item

  AvailabilityResult({
    required this.itemId,
    required this.itemName,
    required this.totalOwned,
    required this.alreadyAllocated,
    required this.rentedQuantity,
    required this.available,
    required this.isAvailable,
    required this.conflicts,
  });

  /// Get the effective available including rentals
  int get effectiveAvailable => available + rentedQuantity;
}

/// Details about an allocation conflict
class AllocationConflict {
  final int eventId;
  final String eventName;
  final DateTime eventStart;
  final DateTime eventEnd;
  final int quantityUsed;

  AllocationConflict({
    required this.eventId,
    required this.eventName,
    required this.eventStart,
    required this.eventEnd,
    required this.quantityUsed,
  });
}

/// Information about a shortage
class ShortageInfo {
  final int itemId;
  final String itemName;
  final int quantityNeeded;
  final int quantityAvailable;
  final int quantityRented;
  final int shortage;          // How many more needed
  final List<AllocationConflict> conflicts;

  ShortageInfo({
    required this.itemId,
    required this.itemName,
    required this.quantityNeeded,
    required this.quantityAvailable,
    required this.quantityRented,
    required this.shortage,
    required this.conflicts,
  });
}

/// Item with its availability info for event planning
class ItemWithAvailability {
  final Item item;
  final AvailabilityResult availability;

  ItemWithAvailability({
    required this.item,
    required this.availability,
  });
}
