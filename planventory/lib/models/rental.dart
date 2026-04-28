import 'rental_item.dart';

/// Represents a rental ticket for materials borrowed from another company
/// A rental can contain multiple items with different quantities
class Rental {
  final int? id;
  final int eventId;           // The event requiring the rental
  
  // Items being rented (stored in rental_items table)
  final List<RentalItem> items;
  
  // Rental details
  final String companyName;    // Company renting from
  final String? companyContact; // Phone/email
  final double? rentalCost;    // Total cost of rental
  final String? currency;      // e.g., EUR, USD
  
  // Pickup details
  final DateTime pickupDate;
  final String? pickupLocation;
  final String? pickupNotes;
  
  // Return details
  final DateTime returnDate;
  final String? returnLocation;
  final String? returnNotes;
  
  // Status tracking
  final RentalStatus status;
  final DateTime? actualPickupDate;  // When actually picked up
  final DateTime? actualReturnDate;  // When actually returned
  final String? returnConfirmation;  // Notes when marking returned

  final int? venueId;  // Optional — which venue/stage this rental is for

  final DateTime createdAt;
  final DateTime updatedAt;

  Rental({
    this.id,
    required this.eventId,
    this.items = const [],
    required this.companyName,
    this.companyContact,
    this.rentalCost,
    this.currency = 'EUR',
    required this.pickupDate,
    this.pickupLocation,
    this.pickupNotes,
    required this.returnDate,
    this.returnLocation,
    this.returnNotes,
    this.status = RentalStatus.pending,
    this.actualPickupDate,
    this.actualReturnDate,
    this.returnConfirmation,
    this.venueId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Check if rental is currently active (picked up but not returned)
  bool get isActive => status == RentalStatus.pickedUp;
  
  /// Check if rental is overdue for return
  bool get isOverdue => 
      isActive && DateTime.now().isAfter(returnDate);
  
  /// Check if pickup is upcoming
  bool get isPickupPending => 
      status == RentalStatus.pending && 
      DateTime.now().isBefore(pickupDate);
  
  /// Total number of items being rented
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  /// Summary of items for display (e.g., "3 items (12 units)")
  String get itemsSummary {
    if (items.isEmpty) return 'No items';
    if (items.length == 1) {
      return '${items.first.itemName ?? 'Item'} (${items.first.quantity})';
    }
    return '${items.length} items ($totalItemCount units)';
  }

  /// Convert to Map for SQLite (without items - they're stored separately)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'company_name': companyName,
      'company_contact': companyContact,
      'rental_cost': rentalCost,
      'currency': currency,
      'pickup_date': pickupDate.toIso8601String(),
      'pickup_location': pickupLocation,
      'pickup_notes': pickupNotes,
      'return_date': returnDate.toIso8601String(),
      'return_location': returnLocation,
      'return_notes': returnNotes,
      'status': status.name,
      'actual_pickup_date': actualPickupDate?.toIso8601String(),
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'return_confirmation': returnConfirmation,
      'venue_id': venueId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create Rental from SQLite Map (items are loaded separately)
  factory Rental.fromMap(Map<String, dynamic> map, {List<RentalItem>? items}) {
    return Rental(
      id: map['id'] as int?,
      eventId: map['event_id'] as int,
      items: items ?? [],
      companyName: map['company_name'] as String,
      companyContact: map['company_contact'] as String?,
      rentalCost: map['rental_cost'] as double?,
      currency: map['currency'] as String? ?? 'EUR',
      pickupDate: DateTime.parse(map['pickup_date'] as String),
      pickupLocation: map['pickup_location'] as String?,
      pickupNotes: map['pickup_notes'] as String?,
      returnDate: DateTime.parse(map['return_date'] as String),
      returnLocation: map['return_location'] as String?,
      returnNotes: map['return_notes'] as String?,
      status: RentalStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RentalStatus.pending,
      ),
      actualPickupDate: map['actual_pickup_date'] != null
          ? DateTime.parse(map['actual_pickup_date'] as String)
          : null,
      actualReturnDate: map['actual_return_date'] != null
          ? DateTime.parse(map['actual_return_date'] as String)
          : null,
      returnConfirmation: map['return_confirmation'] as String?,
      venueId: map['venue_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create a copy with updated fields
  Rental copyWith({
    int? id,
    int? eventId,
    List<RentalItem>? items,
    String? companyName,
    String? companyContact,
    double? rentalCost,
    String? currency,
    DateTime? pickupDate,
    String? pickupLocation,
    String? pickupNotes,
    DateTime? returnDate,
    String? returnLocation,
    String? returnNotes,
    RentalStatus? status,
    DateTime? actualPickupDate,
    DateTime? actualReturnDate,
    String? returnConfirmation,
    int? venueId,
    bool clearVenueId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rental(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      items: items ?? this.items,
      companyName: companyName ?? this.companyName,
      companyContact: companyContact ?? this.companyContact,
      rentalCost: rentalCost ?? this.rentalCost,
      currency: currency ?? this.currency,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupNotes: pickupNotes ?? this.pickupNotes,
      returnDate: returnDate ?? this.returnDate,
      returnLocation: returnLocation ?? this.returnLocation,
      returnNotes: returnNotes ?? this.returnNotes,
      status: status ?? this.status,
      actualPickupDate: actualPickupDate ?? this.actualPickupDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      returnConfirmation: returnConfirmation ?? this.returnConfirmation,
      venueId: clearVenueId ? null : (venueId ?? this.venueId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Status of a rental ticket
enum RentalStatus {
  pending,    // Created but not picked up yet
  pickedUp,   // Materials have been picked up
  returned,   // Materials have been returned
  cancelled,  // Rental was cancelled
}

extension RentalStatusExtension on RentalStatus {
  String get displayName {
    switch (this) {
      case RentalStatus.pending:
        return 'Pending Pickup';
      case RentalStatus.pickedUp:
        return 'In Use';
      case RentalStatus.returned:
        return 'Returned';
      case RentalStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  String get icon {
    switch (this) {
      case RentalStatus.pending:
        return '⏳';
      case RentalStatus.pickedUp:
        return '📦';
      case RentalStatus.returned:
        return '✅';
      case RentalStatus.cancelled:
        return '❌';
    }
  }
}
