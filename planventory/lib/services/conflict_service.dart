import '../../models/models.dart';
import 'database/item_dao.dart';
import 'database/event_dao.dart';
import 'database/allocation_dao.dart';

/// Service to detect inventory conflicts between events
class ConflictService {
  final ItemDao _itemDao = ItemDao();
  final EventDao _eventDao = EventDao();
  final AllocationDao _allocationDao = AllocationDao();

  /// Check all events for conflicts and return warnings
  Future<List<InventoryWarning>> checkAllConflicts() async {
    final warnings = <InventoryWarning>[];
    final items = await _itemDao.getAll();
    final upcomingEvents = await _eventDao.getUpcoming();

    for (final item in items) {
      final itemWarnings = await checkItemConflicts(item, upcomingEvents);
      warnings.addAll(itemWarnings);
    }

    return warnings;
  }

  /// Check for conflicts on a specific item
  Future<List<InventoryWarning>> checkItemConflicts(
      Item item, List<Event> events) async {
    final warnings = <InventoryWarning>[];

    // Group events by overlapping periods
    final overlappingGroups = _findOverlappingEventGroups(events);

    for (final group in overlappingGroups) {
      // Calculate total needed during this overlap period
      int totalNeeded = 0;
      final eventsUsingItem = <Event>[];

      for (final event in group) {
        final allocation =
            await _allocationDao.getByEventAndItem(event.id!, item.id!);
        if (allocation != null) {
          totalNeeded += allocation.quantityNeeded;
          eventsUsingItem.add(event);
        }
      }

      // Check if we have enough
      if (eventsUsingItem.length > 1 && totalNeeded > item.quantity) {
        warnings.add(InventoryWarning.shortage(
          item: item,
          events: eventsUsingItem,
          neededQuantity: totalNeeded,
          availableQuantity: item.quantity,
        ));
      } else if (eventsUsingItem.length > 1) {
        // Multiple events use this item during overlap - warn even if enough
        warnings.add(InventoryWarning.overlap(
          item: item,
          overlappingEvents: eventsUsingItem,
        ));
      }
    }

    return warnings;
  }

  /// Check what happens if we reduce item quantity
  Future<List<InventoryWarning>> checkQuantityReduction(
      Item item, int newQuantity) async {
    final warnings = <InventoryWarning>[];
    final upcomingEvents = await _eventDao.getUpcoming();

    for (final event in upcomingEvents) {
      final allocation =
          await _allocationDao.getByEventAndItem(event.id!, item.id!);
      if (allocation != null && allocation.quantityNeeded > newQuantity) {
        warnings.add(InventoryWarning(
          type: WarningType.quantityReduced,
          severity: WarningSeverity.warning,
          message:
              'Reducing ${item.name} to $newQuantity will affect "${event.name}" '
              'which needs ${allocation.quantityNeeded}.',
          affectedItem: item,
          affectedEvents: [event],
          shortageAmount: allocation.quantityNeeded - newQuantity,
        ));
      }
    }

    return warnings;
  }

  /// Check what happens if we delete an item
  Future<List<InventoryWarning>> checkItemDeletion(Item item) async {
    final events = await _eventDao.getEventsUsingItem(item.id!);
    final upcomingEvents = events.where((e) => e.isUpcoming).toList();

    if (upcomingEvents.isEmpty) {
      return [];
    }

    return [
      InventoryWarning.itemRemoved(
        item: item,
        affectedEvents: upcomingEvents,
      ),
    ];
  }

  /// Check availability of an item for a specific date range
  Future<ItemAvailability> checkItemAvailability(
      Item item, DateTime start, DateTime end) async {
    final totalNeeded =
        await _allocationDao.getTotalNeededInDateRange(item.id!, start, end);
    final available = item.quantity - totalNeeded;

    return ItemAvailability(
      item: item,
      totalQuantity: item.quantity,
      allocatedQuantity: totalNeeded,
      availableQuantity: available > 0 ? available : 0,
      startDate: start,
      endDate: end,
    );
  }

  /// Find groups of overlapping events
  List<List<Event>> _findOverlappingEventGroups(List<Event> events) {
    if (events.isEmpty) return [];

    // Sort by start date
    final sorted = List<Event>.from(events)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final groups = <List<Event>>[];
    var currentGroup = <Event>[sorted.first];
    var currentEnd = sorted.first.endDate;

    for (var i = 1; i < sorted.length; i++) {
      final event = sorted[i];
      if (event.startDate.isBefore(currentEnd)) {
        // Overlaps with current group
        currentGroup.add(event);
        if (event.endDate.isAfter(currentEnd)) {
          currentEnd = event.endDate;
        }
      } else {
        // Start a new group
        if (currentGroup.length > 1) {
          groups.add(currentGroup);
        }
        currentGroup = [event];
        currentEnd = event.endDate;
      }
    }

    // Don't forget the last group
    if (currentGroup.length > 1) {
      groups.add(currentGroup);
    }

    return groups;
  }
}

/// Represents availability of an item during a time period
class ItemAvailability {
  final Item item;
  final int totalQuantity;
  final int allocatedQuantity;
  final int availableQuantity;
  final DateTime startDate;
  final DateTime endDate;

  ItemAvailability({
    required this.item,
    required this.totalQuantity,
    required this.allocatedQuantity,
    required this.availableQuantity,
    required this.startDate,
    required this.endDate,
  });

  bool get isAvailable => availableQuantity > 0;
  bool get isFullyAllocated => availableQuantity == 0;
}
