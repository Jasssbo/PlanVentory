import 'package:flutter/foundation.dart';
import 'inventory_provider.dart';
import 'event_provider.dart';

/// Global app state provider for coordinating refreshes across all screens
/// When refreshAll() is called, all listening screens will be notified
class AppStateProvider with ChangeNotifier {
  final InventoryProvider _inventoryProvider;
  final EventProvider _eventProvider;
  
  int _refreshCounter = 0;
  bool _isRefreshing = false;
  int _selectedTabIndex = 0;
  
  AppStateProvider({
    required InventoryProvider inventoryProvider,
    required EventProvider eventProvider,
  }) : _inventoryProvider = inventoryProvider,
       _eventProvider = eventProvider;
  
  /// Counter that increments on each refresh, allowing screens to detect changes
  int get refreshCounter => _refreshCounter;
  
  /// Currently selected tab index in the main navigation
  int get selectedTabIndex => _selectedTabIndex;
  
  /// Navigate to a specific tab
  void navigateToTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }
  
  /// Whether a global refresh is in progress
  bool get isRefreshing => _isRefreshing;
  
  /// Refresh all data across the app
  /// This reloads inventory, events, and notifies all listeners
  Future<void> refreshAll() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    notifyListeners();
    
    try {
      // Refresh both providers in parallel
      await Future.wait([
        _inventoryProvider.loadItems(),
        _eventProvider.loadEvents(),
      ]);
      
      _refreshCounter++;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
  
  /// Trigger a refresh of all data
  /// Use this when a screen has made changes that other screens need to see
  Future<void> notifyRefreshNeeded() async {
    // Actually reload the data so all screens see the changes
    await refreshAll();
  }
}
