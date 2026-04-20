import 'event.dart';
import 'item.dart';

/// Warning types for inventory conflicts
enum WarningType {
  itemShortage,       // Not enough items for overlapping events
  itemRemoved,        // Item was removed from inventory
  quantityReduced,    // Item quantity was reduced
  eventOverlap,       // Events overlap and share materials
}

/// Severity levels for warnings
enum WarningSeverity {
  info,     // Just informational
  warning,  // Needs attention
  critical, // Immediate action required
}

/// Represents a warning about material/event conflicts
class InventoryWarning {
  final WarningType type;
  final WarningSeverity severity;
  final String message;
  final Item? affectedItem;
  final List<Event> affectedEvents;
  final int? shortageAmount; // How many items are missing
  final DateTime createdAt;

  InventoryWarning({
    required this.type,
    required this.severity,
    required this.message,
    this.affectedItem,
    this.affectedEvents = const [],
    this.shortageAmount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a shortage warning when item quantity is insufficient
  factory InventoryWarning.shortage({
    required Item item,
    required List<Event> events,
    required int neededQuantity,
    required int availableQuantity,
  }) {
    final shortage = neededQuantity - availableQuantity;
    return InventoryWarning(
      type: WarningType.itemShortage,
      severity: WarningSeverity.critical,
      message:
          '${item.name}: Need $neededQuantity but only $availableQuantity available. '
          'Short by $shortage for ${events.length} event(s).',
      affectedItem: item,
      affectedEvents: events,
      shortageAmount: shortage,
    );
  }

  /// Create a warning when events overlap and share materials
  factory InventoryWarning.overlap({
    required Item item,
    required List<Event> overlappingEvents,
  }) {
    final eventNames = overlappingEvents.map((e) => e.name).join(', ');
    return InventoryWarning(
      type: WarningType.eventOverlap,
      severity: WarningSeverity.warning,
      message:
          '${item.name} is needed by overlapping events: $eventNames',
      affectedItem: item,
      affectedEvents: overlappingEvents,
    );
  }

  /// Create a warning when item is removed from inventory
  factory InventoryWarning.itemRemoved({
    required Item item,
    required List<Event> affectedEvents,
  }) {
    return InventoryWarning(
      type: WarningType.itemRemoved,
      severity: WarningSeverity.critical,
      message:
          '${item.name} was removed but is needed by ${affectedEvents.length} event(s).',
      affectedItem: item,
      affectedEvents: affectedEvents,
    );
  }
}
