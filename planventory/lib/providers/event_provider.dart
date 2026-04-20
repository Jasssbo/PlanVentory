import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// State management for events
class EventProvider with ChangeNotifier {
  final EventDao _eventDao = EventDao();
  final AllocationDao _allocationDao = AllocationDao();
  final RentalDao _rentalDao = RentalDao();
  final ConflictService _conflictService = ConflictService();
  final AvailabilityService _availabilityService = AvailabilityService();

  List<Event> _events = [];
  List<Event> _upcomingEvents = [];
  List<Event> _pastEvents = [];
  Set<int> _eventsWithConflicts = {}; // IDs of events with material shortages
  Set<int> _eventsWithRentals = {}; // IDs of events with active/pending rentals
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Event> get events => _events;
  List<Event> get upcomingEvents => _upcomingEvents;
  List<Event> get pastEvents => _pastEvents;
  Set<int> get eventsWithConflicts => _eventsWithConflicts;
  Set<int> get eventsWithRentals => _eventsWithRentals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if an event has unresolved conflicts (material shortages)
  bool hasConflict(int eventId) => _eventsWithConflicts.contains(eventId);

  /// Check if an event has active or pending rentals
  bool hasRental(int eventId) => _eventsWithRentals.contains(eventId);

  /// Get the status of an event for visual indicators
  EventStatus getEventStatus(int eventId) {
    // Check for unresolved conflicts first - red takes priority
    if (_eventsWithConflicts.contains(eventId)) {
      return EventStatus.needsRental;
    }
    // Event has rentals and all shortages are covered
    if (_eventsWithRentals.contains(eventId)) {
      return EventStatus.hasRental;
    }
    // Everything is fine
    return EventStatus.ok;
  }

  /// Load all events from database
  Future<void> loadEvents({bool showLoading = false}) async {
    // Only show loading indicator on initial load (when lists are empty)
    final isInitialLoad = _events.isEmpty;
    if (isInitialLoad || showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      _events = await _eventDao.getAll();
      _upcomingEvents = await _eventDao.getUpcoming();
      _pastEvents = await _eventDao.getPast();
      
      // Check for conflicts on all upcoming events
      await _checkAllConflicts();
    } catch (e) {
      _error = 'Failed to load events: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Check all upcoming events for material shortages
  Future<void> _checkAllConflicts() async {
    _eventsWithConflicts = {};
    _eventsWithRentals = {};
    
    for (final event in _upcomingEvents) {
      if (event.id == null) continue;
      
      // Check for active/pending rentals
      final rentals = await _rentalDao.getForEvent(event.id!);
      final hasActiveOrPendingRental = rentals.any((r) => 
        r.status == RentalStatus.pending || r.status == RentalStatus.pickedUp);
      
      if (hasActiveOrPendingRental) {
        _eventsWithRentals.add(event.id!);
      }
      
      // Check for material shortages
      final shortages = await _availabilityService.getShortagesForEvent(
        eventId: event.id!,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      
      if (shortages.isNotEmpty) {
        _eventsWithConflicts.add(event.id!);
      }
    }
  }

  /// Manually refresh conflict status for all events
  Future<void> refreshConflicts() async {
    await _checkAllConflicts();
    notifyListeners();
  }

  /// Add a new event
  Future<int> addEvent(Event event) async {
    try {
      final id = await _eventDao.insert(event);
      // Reload all events from database to ensure consistency
      await loadEvents();
      return id;
    } catch (e) {
      _error = 'Failed to add event: $e';
      notifyListeners();
      return -1;
    }
  }

  /// Update an event
  Future<void> updateEvent(Event event) async {
    try {
      await _eventDao.update(event);
      await loadEvents(); // Reload to properly sort
    } catch (e) {
      _error = 'Failed to update event: $e';
      notifyListeners();
    }
  }

  /// Delete an event
  Future<void> deleteEvent(int id) async {
    try {
      await _allocationDao.deleteForEvent(id);
      await _eventDao.delete(id);
      // Reload all events from database to ensure consistency
      await loadEvents();
    } catch (e) {
      _error = 'Failed to delete event: $e';
      notifyListeners();
    }
  }

  /// Get events in a specific month (for calendar view)
  Future<List<Event>> getEventsForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return await _eventDao.getInDateRange(start, end);
  }

  /// Allocate an item to an event
  Future<List<InventoryWarning>> allocateItem(
      int eventId, int itemId, int quantity) async {
    // Get event to verify it exists
    _events.firstWhere((e) => e.id == eventId);
    final allocation = Allocation(
      eventId: eventId,
      itemId: itemId,
      quantityNeeded: quantity,
    );

    await _allocationDao.insert(allocation);

    // Check for conflicts after allocation
    return await _conflictService.checkAllConflicts();
  }

  /// Remove an item allocation from an event
  Future<void> removeAllocation(int eventId, int itemId) async {
    final allocation =
        await _allocationDao.getByEventAndItem(eventId, itemId);
    if (allocation != null) {
      await _allocationDao.delete(allocation.id!);
    }
    notifyListeners();
  }

  /// Get all allocations for an event
  Future<List<Allocation>> getEventAllocations(int eventId) async {
    return await _allocationDao.getForEvent(eventId);
  }
}
