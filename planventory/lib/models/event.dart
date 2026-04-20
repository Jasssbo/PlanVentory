/// Represents an event that requires materials
class Event {
  final int? id;
  final String name;
  final String? description;
  final String? location;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    this.id,
    required this.name,
    this.description,
    this.location,
    required this.startDate,
    required this.endDate,
    this.status = 'upcoming',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Check if event is in the past
  bool get isPast => endDate.isBefore(DateTime.now());

  /// Check if event is currently ongoing
  bool get isOngoing {
    final now = DateTime.now();
    return startDate.isBefore(now) && endDate.isAfter(now);
  }

  /// Check if event is upcoming
  bool get isUpcoming => startDate.isAfter(DateTime.now());

  /// Duration of the event
  Duration get duration => endDate.difference(startDate);

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create Event from SQLite Map
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      location: map['location'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      status: map['status'] as String? ?? 'upcoming',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create a copy with updated fields
  Event copyWith({
    int? id,
    String? name,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
