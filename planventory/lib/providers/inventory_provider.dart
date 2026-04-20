import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// State management for inventory items
class InventoryProvider with ChangeNotifier {
  final ItemDao _itemDao = ItemDao();
  final ConflictService _conflictService = ConflictService();

  List<Item> _items = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Item> get items => _items;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all items from database
  Future<void> loadItems({bool showLoading = false}) async {
    // Only show loading indicator on initial load (when lists are empty)
    final isInitialLoad = _items.isEmpty;
    if (isInitialLoad || showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      _items = await _itemDao.getAll();
      _categories = await _itemDao.getCategories();
    } catch (e) {
      _error = 'Failed to load items: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new item
  Future<List<InventoryWarning>> addItem(Item item) async {
    try {
      await _itemDao.insert(item);
      // Reload all items from database to ensure consistency
      await loadItems();
      return []; // No warnings for new items
    } catch (e) {
      _error = 'Failed to add item: $e';
      notifyListeners();
      return [];
    }
  }

  /// Update an item (returns warnings if changes affect events)
  Future<List<InventoryWarning>> updateItem(Item item) async {
    final warnings = <InventoryWarning>[];

    try {
      // Check if quantity was reduced
      final existingItem = _items.firstWhere((i) => i.id == item.id);
      if (item.quantity < existingItem.quantity) {
        final quantityWarnings =
            await _conflictService.checkQuantityReduction(item, item.quantity);
        warnings.addAll(quantityWarnings);
      }

      await _itemDao.update(item);
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = item;
      }
      _categories = await _itemDao.getCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update item: $e';
      notifyListeners();
    }

    return warnings;
  }

  /// Delete an item (returns warnings if item is allocated to events)
  Future<List<InventoryWarning>> deleteItem(int id) async {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      final warnings = await _conflictService.checkItemDeletion(item);

      await _itemDao.delete(id);
      _items.removeWhere((i) => i.id == id);
      _categories = await _itemDao.getCategories();
      notifyListeners();

      return warnings;
    } catch (e) {
      _error = 'Failed to delete item: $e';
      notifyListeners();
      return [];
    }
  }

  /// Search items by name
  Future<List<Item>> searchItems(String query) async {
    return await _itemDao.search(query);
  }

  /// Get items by category
  List<Item> getByCategory(String category) {
    return _items.where((i) => i.category == category).toList();
  }
}
