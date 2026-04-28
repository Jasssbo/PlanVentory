/// Data class for items to be included in a rental
/// Used during rental creation to represent items before saving
class RentalItemData {
  final int itemId;
  final String itemName;
  int quantity;
  double? itemCost;

  RentalItemData({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.itemCost,
  });
}
