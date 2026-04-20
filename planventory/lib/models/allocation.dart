/// Links an Item to an Event with quantity needed
/// This is the junction table for the many-to-many relationship
class Allocation {
  final int? id;
  final int eventId;
  final int itemId;
  final int quantityNeeded; // How many of this item the event needs
  final String? notes;
  final DateTime createdAt;

  Allocation({
    this.id,
    required this.eventId,
    required this.itemId,
    this.quantityNeeded = 1,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'item_id': itemId,
      'quantity_needed': quantityNeeded,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create Allocation from SQLite Map
  factory Allocation.fromMap(Map<String, dynamic> map) {
    return Allocation(
      id: map['id'] as int?,
      eventId: map['event_id'] as int,
      itemId: map['item_id'] as int,
      quantityNeeded: map['quantity_needed'] as int? ?? 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Create a copy with updated fields
  Allocation copyWith({
    int? id,
    int? eventId,
    int? itemId,
    int? quantityNeeded,
    String? notes,
    DateTime? createdAt,
  }) {
    return Allocation(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      itemId: itemId ?? this.itemId,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
