import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../widgets/edit_rental_dialog.dart';

/// Screen to display and manage all rental tickets
class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  final RentalDao _rentalDao = RentalDao();
  final EventDao _eventDao = EventDao();
  final AllocationDao _allocationDao = AllocationDao();
  final ItemDao _itemDao = ItemDao();
  
  List<Rental> _rentals = [];
  Map<int, Event> _eventsCache = {};
  final Map<int, List<EventItemUsage>> _rentalEventUsages = {}; // rental.id -> list of event usages
  bool _isLoading = true;
  String _selectedFilter = 'active'; // 'all', 'active', 'pending', 'overdue', 'returned'
  int _lastRefreshCounter = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for global refresh triggers
    final appState = context.read<AppStateProvider>();
    if (_lastRefreshCounter != appState.refreshCounter) {
      _lastRefreshCounter = appState.refreshCounter;
      if (_lastRefreshCounter > 0) { // Skip initial
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _rentals = await _rentalDao.getAll();
      
      // Cache events for display
      final events = await _eventDao.getAll();
      _eventsCache = {for (var event in events) event.id!: event};
      
      // For each rental, find which events use its items
      for (final rental in _rentals) {
        final usages = await _getEventUsagesForRental(rental, events);
        _rentalEventUsages[rental.id!] = usages;
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to load rentals: $e');
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  /// Get which events use items from this rental during the rental period
  Future<List<EventItemUsage>> _getEventUsagesForRental(Rental rental, List<Event> allEvents) async {
    final usages = <EventItemUsage>[];
    
    // Get item IDs from this rental
    final rentalItemIds = rental.items.map((i) => i.itemId).toSet();
    if (rentalItemIds.isEmpty) return usages;
    
    // Find events that overlap with rental period
    for (final event in allEvents) {
      // Check if event dates overlap with rental period
      if (event.endDate.isBefore(rental.pickupDate) || 
          event.startDate.isAfter(rental.returnDate)) {
        continue; // No overlap
      }
      
      // Get allocations for this event with matching items
      final eventAllocations = await _allocationDao.getForEvent(event.id!);
      
      for (final allocation in eventAllocations) {
        if (rentalItemIds.contains(allocation.itemId)) {
          // Find the rental item to get the item name
          final rentalItem = rental.items.firstWhere(
            (i) => i.itemId == allocation.itemId,
            orElse: () => rental.items.first,
          );
          
          usages.add(EventItemUsage(
            eventId: event.id!,
            eventName: event.name,
            itemId: allocation.itemId,
            itemName: rentalItem.itemName ?? 'Item #${allocation.itemId}',
            quantity: allocation.quantityNeeded,
          ));
        }
      }
    }
    
    return usages;
  }

  List<Rental> get _filteredRentals {
    switch (_selectedFilter) {
      case 'active':
        return _rentals.where((r) => r.status == RentalStatus.pickedUp).toList();
      case 'pending':
        return _rentals.where((r) => r.status == RentalStatus.pending).toList();
      case 'overdue':
        return _rentals.where((r) => r.isOverdue).toList();
      case 'returned':
        return _rentals.where((r) => r.status == RentalStatus.returned).toList();
      default:
        return _rentals;
    }
  }

  int get _overdueCount => _rentals.where((r) => r.isOverdue).length;
  int get _activeCount => _rentals.where((r) => r.status == RentalStatus.pickedUp).length;
  int get _pendingCount => _rentals.where((r) => r.status == RentalStatus.pending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentals'),
        actions: [
          if (_overdueCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: context.colorScheme.error,
                label: Text(
                  '$_overdueCount overdue',
                  style: TextStyle(
                    color: context.colorScheme.onError,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Trigger global refresh to update all screens
                await context.read<AppStateProvider>().refreshAll();
                await _loadData();
              },
              child: Column(
                children: [
                  _buildFilterChips(context),
                  _buildSummaryCards(context),
                  Expanded(
                    child: _filteredRentals.isEmpty
                        ? _buildEmptyState(context)
                        : _buildRentalsList(context),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: Spacing.horizontalMd,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _selectedFilter == 'all',
            onSelected: () => setState(() => _selectedFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active ($_activeCount)',
            selected: _selectedFilter == 'active',
            onSelected: () => setState(() => _selectedFilter = 'active'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pending ($_pendingCount)',
            selected: _selectedFilter == 'pending',
            onSelected: () => setState(() => _selectedFilter = 'pending'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Overdue ($_overdueCount)',
            selected: _selectedFilter == 'overdue',
            onSelected: () => setState(() => _selectedFilter = 'overdue'),
            isError: _overdueCount > 0,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Returned',
            selected: _selectedFilter == 'returned',
            onSelected: () => setState(() => _selectedFilter = 'returned'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    if (_rentals.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: Spacing.paddingMd,
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.hourglass_top,
              label: 'Pending',
              value: '$_pendingCount',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.swap_horiz,
              label: 'Active',
              value: '$_activeCount',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.warning_amber,
              label: 'Overdue',
              value: '$_overdueCount',
              color: _overdueCount > 0 ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'active':
        message = 'No active rentals';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        message = 'No pending pickups';
        icon = Icons.hourglass_empty;
        break;
      case 'overdue':
        message = 'No overdue returns - great!';
        icon = Icons.celebration;
        break;
      case 'returned':
        message = 'No returned rentals yet';
        icon = Icons.history;
        break;
      default:
        message = 'No rentals yet\n\nRentals are created when you add materials to an event that exceed your inventory.';
        icon = Icons.receipt_long_outlined;
    }
    
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: context.colorScheme.outline),
              const SizedBox(height: 16),
              Padding(
                padding: Spacing.horizontalLg,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRentalsList(BuildContext context) {
    final rentals = _filteredRentals;
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: rentals.length,
      itemBuilder: (context, index) {
        final rental = rentals[index];
        final event = _eventsCache[rental.eventId];
        final eventUsages = _rentalEventUsages[rental.id] ?? [];
        
        return _RentalCard(
          rental: rental,
          eventName: event?.name ?? 'Unknown Event',
          eventUsages: eventUsages,
          onMarkPickedUp: rental.status == RentalStatus.pending
              ? () => _markPickedUp(rental)
              : null,
          onMarkReturned: rental.status == RentalStatus.pickedUp
              ? () => _markReturned(rental)
              : null,
          onEdit: () => _editRental(rental),
          onDelete: () => _deleteRental(rental),
        );
      },
    );
  }

  Future<void> _markPickedUp(Rental rental) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pickup'),
        content: Text('Mark rental from "${rental.companyName}" as picked up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Pickup'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _rentalDao.markPickedUp(rental.id!);
      await _loadData();
      if (mounted) {
        context.showSuccess('Rental marked as picked up');
      }
    }
  }

  Future<void> _markReturned(Rental rental) async {
    final itemsList = rental.items.map((item) => 
      '• ${item.itemName ?? "Item #${item.itemId}"} × ${item.quantity}'
    ).join('\n');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark rental from "${rental.companyName}" as returned?'),
            const SizedBox(height: 16),
            Text(
              'Items:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(itemsList.isEmpty ? 'No items' : itemsList),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _rentalDao.markReturned(rental.id!);
      await _loadData();
      if (mounted) {
        context.showSuccess('Rental marked as returned');
      }
    }
  }

  Future<void> _deleteRental(Rental rental) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rental?'),
        content: Text('Delete rental from "${rental.companyName}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _rentalDao.delete(rental.id!);
      await _loadData();
      if (mounted) {
        context.showSuccess('Rental deleted');
      }
    }
  }

  Future<void> _editRental(Rental rental) async {
    // Get all available items for the dialog
    final availableItems = await _itemDao.getAll();
    
    if (!mounted) return;
    
    final updatedRental = await showDialog<Rental>(
      context: context,
      builder: (dialogContext) => EditRentalDialog(
        rental: rental,
        availableItems: availableItems,
      ),
    );
    
    if (updatedRental != null) {
      await _rentalDao.update(updatedRental);
      await _loadData();
      if (mounted) {
        context.read<AppStateProvider>().notifyRefreshNeeded();
        context.showSuccess('Rental updated');
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool isError;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: isError && !selected ? context.colorScheme.errorContainer : null,
      selectedColor: isError ? context.colorScheme.error : null,
      labelStyle: TextStyle(
        color: selected && isError ? context.colorScheme.onError : null,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final Rental rental;
  final String eventName;
  final List<EventItemUsage> eventUsages;
  final VoidCallback? onMarkPickedUp;
  final VoidCallback? onMarkReturned;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RentalCard({
    required this.rental,
    required this.eventName,
    this.eventUsages = const [],
    this.onMarkPickedUp,
    this.onMarkReturned,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isOverdue = rental.isOverdue;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOverdue ? colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusBadge(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.companyName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? colorScheme.onErrorContainer : null,
                        ),
                      ),
                      Text(
                        'For: $eventName',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: isOverdue 
                              ? colorScheme.onErrorContainer.withAlpha(180)
                              : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Items info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: isOverdue ? colorScheme.onErrorContainer : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.itemsSummary,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isOverdue ? colorScheme.onErrorContainer : null,
                        ),
                      ),
                      // Show individual items if more than one
                      if (rental.items.length > 1) ...[
                        const SizedBox(height: 4),
                        ...rental.items.map((item) => Padding(
                          padding: const EdgeInsets.only(left: 4, top: 2),
                          child: Text(
                            '• ${item.itemName ?? "Item #${item.itemId}"} × ${item.quantity}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: isOverdue 
                                  ? colorScheme.onErrorContainer.withAlpha(200)
                                  : colorScheme.outline,
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
                if (rental.rentalCost != null)
                  Text(
                    '${rental.currency ?? "EUR"} ${rental.rentalCost!.toStringAsFixed(2)}',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? colorScheme.onErrorContainer : colorScheme.primary,
                    ),
                  ),
              ],
            ),
            
            // Show which events use items from this rental
            if (eventUsages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildEventUsagesSection(context, colorScheme, isOverdue),
            ],
            
            const SizedBox(height: 8),
            
            // Dates
            Row(
              children: [
                Expanded(
                  child: _DateInfo(
                    icon: Icons.arrow_upward,
                    label: 'Pickup',
                    date: rental.pickupDate,
                    actualDate: rental.actualPickupDate,
                    isOverdue: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateInfo(
                    icon: Icons.arrow_downward,
                    label: 'Return',
                    date: rental.returnDate,
                    actualDate: rental.actualReturnDate,
                    isOverdue: isOverdue,
                  ),
                ),
              ],
            ),
            
            // Contact info
            if (rental.companyContact != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: isOverdue 
                        ? colorScheme.onErrorContainer.withAlpha(180)
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rental.companyContact!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: isOverdue 
                          ? colorScheme.onErrorContainer.withAlpha(180)
                          : colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
            
            // Action buttons
            if (onMarkPickedUp != null || onMarkReturned != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onMarkPickedUp != null)
                    FilledButton.icon(
                      onPressed: onMarkPickedUp,
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Picked Up'),
                    ),
                  if (onMarkReturned != null)
                    FilledButton.icon(
                      onPressed: onMarkReturned,
                      icon: const Icon(Icons.assignment_return),
                      label: const Text('Mark Returned'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isOverdue 
                            ? colorScheme.error 
                            : colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final colorScheme = context.colorScheme;
    Color bgColor;
    Color textColor;
    IconData icon;
    
    if (rental.isOverdue) {
      bgColor = colorScheme.error;
      textColor = colorScheme.onError;
      icon = Icons.warning_amber;
    } else {
      switch (rental.status) {
        case RentalStatus.pending:
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade800;
          icon = Icons.hourglass_top;
          break;
        case RentalStatus.pickedUp:
          bgColor = Colors.blue.shade100;
          textColor = Colors.blue.shade800;
          icon = Icons.swap_horiz;
          break;
        case RentalStatus.returned:
          bgColor = Colors.green.shade100;
          textColor = Colors.green.shade800;
          icon = Icons.check_circle;
          break;
        case RentalStatus.cancelled:
          bgColor = Colors.grey.shade200;
          textColor = Colors.grey.shade700;
          icon = Icons.cancel;
          break;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: textColor, size: 24),
    );
  }
  
  Widget _buildEventUsagesSection(BuildContext context, ColorScheme colorScheme, bool isOverdue) {
    // Group usages by event
    final byEvent = <String, List<EventItemUsage>>{};
    for (final usage in eventUsages) {
      byEvent.putIfAbsent(usage.eventName, () => []).add(usage);
    }
    
    // Remove the primary event if there's only one event (already shown as "For: eventName")
    if (byEvent.length == 1 && byEvent.keys.first == eventName) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue 
            ? colorScheme.onErrorContainer.withAlpha(20)
            : colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note,
                size: 16,
                color: isOverdue ? colorScheme.onErrorContainer : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Events using these materials:',
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? colorScheme.onErrorContainer : colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...byEvent.entries.map((entry) {
            final eventName = entry.key;
            final usages = entry.value;
            final itemsList = usages.map((u) => '${u.itemName} ×${u.quantity}').join(', ');
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: context.textTheme.bodySmall),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: context.textTheme.bodySmall?.copyWith(
                          color: isOverdue 
                              ? colorScheme.onErrorContainer.withAlpha(200)
                              : colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: eventName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ': $itemsList'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DateInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime date;
  final DateTime? actualDate;
  final bool isOverdue;

  const _DateInfo({
    required this.icon,
    required this.label,
    required this.date,
    this.actualDate,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final displayDate = actualDate ?? date;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isOverdue ? colorScheme.error : colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: isOverdue 
                      ? colorScheme.onErrorContainer.withAlpha(180)
                      : colorScheme.outline,
                ),
              ),
              Text(
                _formatDate(displayDate),
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isOverdue ? colorScheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Represents how a rental item is used by an event
class EventItemUsage {
  final int eventId;
  final String eventName;
  final int itemId;
  final String itemName;
  final int quantity;
  
  EventItemUsage({
    required this.eventId,
    required this.eventName,
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });
}
