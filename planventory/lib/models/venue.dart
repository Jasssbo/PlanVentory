/// Represents a venue/stage within an event.
/// An event can have multiple venues (e.g., "Main Stage", "Stage 2", "Backstage").
/// Allocations and rentals can be optionally associated with a venue.
class Venue {
  final int? id;
  final int eventId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;

  Venue({
    this.id,
    required this.eventId,
    required this.name,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Venue.fromMap(Map<String, dynamic> map) {
    return Venue(
      id: map['id'] as int?,
      eventId: map['event_id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Venue copyWith({
    int? id,
    int? eventId,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Venue(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
