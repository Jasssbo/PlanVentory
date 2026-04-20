/// Represents an item within a rental ticket
/// A rental can have multiple items, each with its own quantity
class RentalItem {
  final int? id;
  final int rentalId;
  final int itemId;
  final int quantity;
  
  // Cached item details (for display purposes, not stored in DB)
  final String? itemName;

  RentalItem({
    this.id,
    required this.rentalId,
    required this.itemId,
    required this.quantity,
    this.itemName,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rental_id': rentalId,
      'item_id': itemId,
      'quantity': quantity,
    };
  }

  /// Create RentalItem from SQLite Map
  factory RentalItem.fromMap(Map<String, dynamic> map, {String? itemName}) {
    return RentalItem(
      id: map['id'] as int?,
      rentalId: map['rental_id'] as int,
      itemId: map['item_id'] as int,
      quantity: map['quantity'] as int,
      itemName: itemName ?? map['item_name'] as String?,
    );
  }

  /// Create a copy with updated fields
  RentalItem copyWith({
    int? id,
    int? rentalId,
    int? itemId,
    int? quantity,
    String? itemName,
  }) {
    return RentalItem(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      itemName: itemName ?? this.itemName,
    );
  }
}
