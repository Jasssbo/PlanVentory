/// Represents an item within a rental ticket
/// A rental can have multiple items, each with its own quantity
class RentalItem {
  final int? id;
  final int rentalId;
  final int itemId;
  final int quantity;
  /// Optional per-item rental cost (e.g. what this specific item costs to rent)
  final double? itemCost;

  // Cached item details (for display purposes, not stored in DB)
  final String? itemName;

  RentalItem({
    this.id,
    required this.rentalId,
    required this.itemId,
    required this.quantity,
    this.itemCost,
    this.itemName,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rental_id': rentalId,
      'item_id': itemId,
      'quantity': quantity,
      'item_cost': itemCost,
    };
  }

  /// Create RentalItem from SQLite Map
  factory RentalItem.fromMap(Map<String, dynamic> map, {String? itemName}) {
    return RentalItem(
      id: map['id'] as int?,
      rentalId: map['rental_id'] as int,
      itemId: map['item_id'] as int,
      quantity: map['quantity'] as int,
      itemCost: map['item_cost'] as double?,
      itemName: itemName ?? map['item_name'] as String?,
    );
  }

  /// Create a copy with updated fields
  RentalItem copyWith({
    int? id,
    int? rentalId,
    int? itemId,
    int? quantity,
    double? itemCost,
    bool clearItemCost = false,
    String? itemName,
  }) {
    return RentalItem(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      itemCost: clearItemCost ? null : (itemCost ?? this.itemCost),
      itemName: itemName ?? this.itemName,
    );
  }
}
