/// Represents an inventory item/material
class Item {
  final int? id;
  final String name;
  final String? description;
  final int quantity; // Total owned
  final String? category;
  final String? imageUrl;
  final bool isRentalOnly; // Items that are never owned, only rented when needed
  final DateTime createdAt;
  final DateTime updatedAt;

  Item({
    this.id,
    required this.name,
    this.description,
    this.quantity = 1,
    this.category,
    this.imageUrl,
    this.isRentalOnly = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'category': category,
      'image_url': imageUrl,
      'is_rental_only': isRentalOnly ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create Item from SQLite Map
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      quantity: map['quantity'] as int? ?? 1,
      category: map['category'] as String?,
      imageUrl: map['image_url'] as String?,
      isRentalOnly: (map['is_rental_only'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create a copy with updated fields
  Item copyWith({
    int? id,
    String? name,
    String? description,
    int? quantity,
    String? category,
    String? imageUrl,
    bool? isRentalOnly,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isRentalOnly: isRentalOnly ?? this.isRentalOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
