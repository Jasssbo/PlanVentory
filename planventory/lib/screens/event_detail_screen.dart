import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import '../widgets/create_rental_dialog.dart';

/// Detailed view for an event with material allocation management
class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _event;
  List<AllocationWithItem> _allocations = [];
  List<Rental> _rentals = [];
  List<ShortageInfo> _shortages = [];
  bool _isLoading = true;

  final AllocationDao _allocationDao = AllocationDao();
  final ItemDao _itemDao = ItemDao();
  final RentalDao _rentalDao = RentalDao();
  final AvailabilityService _availabilityService = AvailabilityService();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load allocations with item details
    final allocations = await _allocationDao.getForEvent(_event.id!);
    final allocationsWithItems = <AllocationWithItem>[];
    
    for (final allocation in allocations) {
      final item = await _itemDao.getById(allocation.itemId);
      if (item != null) {
        allocationsWithItems.add(AllocationWithItem(
          allocation: allocation,
          item: item,
        ));
      }
    }

    // Load rentals
    final rentals = await _rentalDao.getForEvent(_event.id!);

    // Check for shortages
    final shortages = await _availabilityService.getShortagesForEvent(
      eventId: _event.id!,
      startDate: _event.startDate,
      endDate: _event.endDate,
    );

    setState(() {
      _allocations = allocationsWithItems;
      _rentals = rentals;
      _shortages = shortages;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditEventDialog(context),
            tooltip: 'Edit Event',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteEvent(context),
            tooltip: 'Delete Event',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Spacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventInfo(context),
                    const SizedBox(height: 24),
                    if (_shortages.isNotEmpty) ...[
                      _buildShortagesSection(context),
                      const SizedBox(height: 24),
                    ],
                    _buildMaterialsSection(context),
                    const SizedBox(height: 24),
                    if (_rentals.isNotEmpty) ...[
                      _buildRentalsSection(context),
                      const SizedBox(height: 24),
                    ],
                    if (_allocations.isNotEmpty) ...[
                      _buildGearValueSection(context),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMaterialDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Material'),
      ),
    );
  }

  Widget _buildEventInfo(BuildContext context) {
    final colorScheme = context.colorScheme;
    
    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusChip(context),
                const Spacer(),
                Text(
                  '${_event.startDate.formatted} - ${_event.endDate.formatted}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
            if (_event.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, 
                    size: 18, 
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _event.location!,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (_event.description != null) ...[
              const SizedBox(height: 12),
              Text(
                _event.description!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final colorScheme = context.colorScheme;
    Color chipColor;
    String label;

    if (_event.isPast) {
      chipColor = colorScheme.outline;
      label = 'Completed';
    } else if (_event.isOngoing) {
      chipColor = colorScheme.tertiary;
      label = 'Ongoing';
    } else {
      chipColor = colorScheme.primary;
      label = 'Upcoming';
    }

    return Chip(
      label: Text(label),
      backgroundColor: chipColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: chipColor, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildShortagesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, color: context.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Material Shortages',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.error,
                ),
              ),
            ),
            if (_shortages.length > 1)
              FilledButton.icon(
                onPressed: () => _showRentAllShortagesDialog(),
                icon: const Icon(Icons.local_shipping, size: 16),
                label: const Text('Rent All'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_shortages.map((shortage) => _buildShortageCard(context, shortage))),
      ],
    );
  }

  Widget _buildShortageCard(BuildContext context, ShortageInfo shortage) {
    final colorScheme = context.colorScheme;
    
    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortage.itemName,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Need ${shortage.quantityNeeded}, only ${shortage.quantityAvailable} available',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      Text(
                        'Short by ${shortage.shortage} units',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showCreateRentalDialog(
                    singleItemId: shortage.itemId,
                    singleItemName: shortage.itemName,
                    singleQuantity: shortage.shortage,
                  ),
                  icon: const Icon(Icons.local_shipping, size: 18),
                  label: const Text('Rent'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (shortage.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Conflicts with:',
                style: context.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              ...shortage.conflicts.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '• ${c.eventName} (${c.quantityUsed} units)',
                  style: context.textTheme.bodySmall,
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: context.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Allocated Materials',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_allocations.length} items',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_allocations.isEmpty)
          Card(
            child: Padding(
              padding: Spacing.paddingLg,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory,
                      size: 48,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No materials allocated yet',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showAddMaterialDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Materials'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_allocations.map((a) => _buildAllocationTile(context, a))),
      ],
    );
  }

  Widget _buildAllocationTile(BuildContext context, AllocationWithItem allocation) {
    final colorScheme = context.colorScheme;
    final isShortage = _shortages.any((s) => s.itemId == allocation.item.id);
    
    return Card(
      color: isShortage 
          ? colorScheme.errorContainer.withValues(alpha: 0.2)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isShortage 
              ? colorScheme.error.withValues(alpha: 0.2)
              : colorScheme.primaryContainer,
          child: Icon(
            Icons.category,
            color: isShortage ? colorScheme.error : colorScheme.primary,
          ),
        ),
        title: Text(allocation.item.name),
        subtitle: Text(
          allocation.item.category ?? 'No category',
          style: TextStyle(color: colorScheme.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${allocation.allocation.quantityNeeded}',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.primary),
              onPressed: () => _showEditAllocationDialog(context, allocation),
              tooltip: 'Edit quantity',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: () => _confirmRemoveAllocation(context, allocation),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGearValueSection(BuildContext context) {
    final colorScheme = context.colorScheme;

    // Only include items that have a unit cost defined
    final valuedAllocations = _allocations
        .where((a) => a.item.unitCost != null && a.item.unitCost! > 0)
        .toList();

    if (valuedAllocations.isEmpty) return const SizedBox.shrink();

    final total = valuedAllocations.fold<double>(
      0,
      (sum, a) => sum + a.item.unitCost! * a.allocation.quantityNeeded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.euro, color: colorScheme.secondary),
            const SizedBox(width: 8),
            Text(
              'Gear Value',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: Spacing.paddingMd,
            child: Column(
              children: [
                ...valuedAllocations.map((a) {
                  final lineValue = a.item.unitCost! * a.allocation.quantityNeeded;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.item.name,
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${a.allocation.quantityNeeded} × €${a.item.unitCost!.toStringAsFixed(2)}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '€${lineValue.toStringAsFixed(2)}',
                            textAlign: TextAlign.end,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Gear Value',
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '€${total.toStringAsFixed(2)}',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (valuedAllocations.length < _allocations.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_allocations.length - valuedAllocations.length} item(s) have no cost set',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRentalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping, color: context.colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(
              'Rentals',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_rentals.map((r) => _buildRentalTile(context, r))),
      ],
    );
  }

  Widget _buildRentalTile(BuildContext context, Rental rental) {
    final colorScheme = context.colorScheme;
    
    Color statusColor;
    switch (rental.status) {
      case RentalStatus.pending:
        statusColor = colorScheme.tertiary;
        break;
      case RentalStatus.pickedUp:
        statusColor = colorScheme.primary;
        break;
      case RentalStatus.returned:
        statusColor = Colors.green;
        break;
      case RentalStatus.cancelled:
        statusColor = colorScheme.outline;
        break;
    }

    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(rental.status.displayName),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                ),
                const Spacer(),
                if (rental.rentalCost != null)
                  Text(
                    '${rental.currency} ${rental.rentalCost!.toStringAsFixed(2)}',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'From ${rental.companyName}',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Show items in the rental
            ...rental.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.itemName ?? 'Item #${item.itemId}'} × ${item.quantity}',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Pickup: ${rental.pickupDate.formatted}',
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.event, size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Return: ${rental.returnDate.formatted}',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
            if (rental.pickupLocation != null) ...[
              const SizedBox(height: 4),
              Text(
                'From: ${rental.pickupLocation}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (rental.status == RentalStatus.pending)
                  FilledButton.tonal(
                    onPressed: () => _markRentalPickedUp(rental),
                    child: const Text('Mark Picked Up'),
                  ),
                if (rental.status == RentalStatus.pickedUp) ...[
                  if (rental.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text('OVERDUE'),
                        backgroundColor: colorScheme.error.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide.none,
                      ),
                    ),
                  FilledButton(
                    onPressed: () => _showConfirmReturnDialog(context, rental),
                    child: const Text('Confirm Return'),
                  ),
                ],
                if (rental.status == RentalStatus.pending ||
                    rental.status == RentalStatus.pickedUp)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: () => _cancelRental(rental),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMaterialDialog(BuildContext context) async {
    final items = context.read<InventoryProvider>().items;
    final existingItemIds = _allocations.map((a) => a.item.id).toSet();
    final availableItems = items.where((i) => !existingItemIds.contains(i.id)).toList();

    // Separate owned items and rental-only items
    final ownedItems = availableItems.where((i) => !i.isRentalOnly).toList();
    final rentalOnlyItems = availableItems.where((i) => i.isRentalOnly).toList();
    
    int selectedTab = 0; // 0 = from inventory, 1 = rental-only
    Item? selectedItem;
    int quantity = 1;
    final newItemNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final needsRental = selectedItem != null && quantity > selectedItem!.quantity;
          
          return AlertDialog(
            title: const Text('Add Material'),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab selector
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('From Inventory'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Rental Only'),
                        icon: Icon(Icons.shopping_cart_outlined),
                      ),
                    ],
                    selected: {selectedTab},
                    onSelectionChanged: (selection) {
                      setDialogState(() {
                        selectedTab = selection.first;
                        selectedItem = null;
                        quantity = 1;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (selectedTab == 0) ...[
                    // From inventory tab
                    if (ownedItems.isEmpty && rentalOnlyItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, 
                              size: 48, 
                              color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text(
                              _allocations.isEmpty 
                                ? 'No items in inventory yet'
                                : 'All items already allocated',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use "Rental Only" tab to add items you\'ll rent',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<Item>(
                        decoration: const InputDecoration(
                          labelText: 'Select Material',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ...ownedItems.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text('${item.name} (${item.quantity} in stock)'),
                            );
                          }),
                          if (rentalOnlyItems.isNotEmpty) ...[
                            const DropdownMenuItem(
                              enabled: false,
                              child: Divider(),
                            ),
                            ...rentalOnlyItems.map((item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Row(
                                  children: [
                                    const Icon(Icons.shopping_cart, size: 16),
                                    const SizedBox(width: 8),
                                    Text('${item.name} (rental only)'),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                        onChanged: (item) {
                          setDialogState(() => selectedItem = item);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Quantity Needed',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: '1',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setDialogState(() => quantity = int.tryParse(value) ?? 1);
                              },
                            ),
                          ),
                          if (selectedItem != null) ...[
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  selectedItem!.isRentalOnly 
                                    ? 'Rental only'
                                    : 'In stock: ${selectedItem!.quantity}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (needsRental || selectedItem!.isRentalOnly)
                                  Text(
                                    'Will need rental',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.tertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (needsRental && !selectedItem!.isRentalOnly) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, 
                                size: 18, 
                                color: theme.colorScheme.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'ll need to rent ${quantity - selectedItem!.quantity} more units',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ] else ...[
                    // Rental-only tab - create new item
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, 
                            size: 18, 
                            color: theme.colorScheme.onTertiaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Create an item you don\'t own but will rent for this event (e.g., special mixer, P.A. system)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newItemNameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g., Yamaha MG16 Mixer',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Quantity Needed',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setDialogState(() => quantity = int.tryParse(value) ?? 1);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: (selectedTab == 0 && selectedItem == null) || 
                           (selectedTab == 1 && newItemNameController.text.trim().isEmpty)
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        if (selectedTab == 0 && selectedItem != null) {
                          await _addMaterial(selectedItem!, quantity);
                        } else if (selectedTab == 1) {
                          await _addRentalOnlyMaterial(
                            newItemNameController.text.trim(), 
                            quantity,
                          );
                        }
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    
    newItemNameController.dispose();
  }

  Future<void> _addRentalOnlyMaterial(String itemName, int quantity) async {
    // Create a new rental-only item in inventory
    final newItem = Item(
      name: itemName,
      quantity: 0, // We don't own any
      isRentalOnly: true,
      category: 'Rental Only',
    );
    
    final itemDao = ItemDao();
    final itemId = await itemDao.insert(newItem);
    
    // Create allocation for this event
    final allocation = Allocation(
      eventId: _event.id!,
      itemId: itemId,
      quantityNeeded: quantity,
    );

    await _allocationDao.insert(allocation);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental-only material added');
    }
  }

  Future<void> _addMaterial(Item item, int quantity) async {
    final allocation = Allocation(
      eventId: _event.id!,
      itemId: item.id!,
      quantityNeeded: quantity,
    );

    await _allocationDao.insert(allocation);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Material added');
    }
  }

  Future<void> _showEditAllocationDialog(
      BuildContext context, AllocationWithItem allocation) async {
    final controller = TextEditingController(
      text: allocation.allocation.quantityNeeded.toString(),
    );
    int currentQty = allocation.allocation.quantityNeeded;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final needsRental = currentQty > allocation.item.quantity;
          
          return AlertDialog(
            title: Text('Edit ${allocation.item.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Quantity Needed',
                    helperText: 'In stock: ${allocation.item.quantity}',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setDialogState(() {
                      currentQty = int.tryParse(value) ?? 1;
                    });
                  },
                ),
                if (needsRental) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                          size: 18, 
                          color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You\'ll need to rent ${currentQty - allocation.item.quantity} more units',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final qty = int.tryParse(controller.text) ?? 1;
                  Navigator.pop(dialogContext);
                  await _updateAllocation(allocation.allocation, qty);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
  }

  Future<void> _updateAllocation(Allocation allocation, int quantity) async {
    await _allocationDao.update(allocation.copyWith(quantityNeeded: quantity));
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Quantity updated');
    }
  }

  Future<void> _confirmRemoveAllocation(
      BuildContext context, AllocationWithItem allocation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Material?'),
        content: Text(
          'Remove ${allocation.item.name} from this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _allocationDao.delete(allocation.allocation.id!);
      await _loadData();
      if (!mounted) return;
      this.context.read<AppStateProvider>().notifyRefreshNeeded();
      this.context.showSuccess('Material removed');
    }
  }

  Future<void> _showCreateRentalDialog({
    List<RentalItemData>? initialItems,
    int? singleItemId,
    String? singleItemName,
    int? singleQuantity,
  }) async {
    // Load all inventory items for the "Add Item" dialog
    final allItems = await _itemDao.getAll();
    
    if (!mounted) return;
    
    // Build initial items list
    List<RentalItemData> itemsToRent = [];
    
    if (initialItems != null) {
      itemsToRent = initialItems;
    } else if (singleItemId != null && singleItemName != null) {
      itemsToRent = [
        RentalItemData(
          itemId: singleItemId,
          itemName: singleItemName,
          quantity: singleQuantity ?? 1,
        ),
      ];
    }
    
    final result = await showDialog<Rental>(
      context: context,
      builder: (dialogContext) => CreateRentalDialog(
        event: _event,
        initialItems: itemsToRent,
        availableItems: allItems,
      ),
    );
    
    if (!mounted) return;
    if (result != null) {
      await _createRental(result);
    }
  }
  
  /// Create a rental for all current shortages
  Future<void> _showRentAllShortagesDialog() async {
    if (_shortages.isEmpty) return;
    
    final initialItems = _shortages.map((s) => RentalItemData(
      itemId: s.itemId,
      itemName: s.itemName,
      quantity: s.shortage,
    )).toList();
    
    await _showCreateRentalDialog(initialItems: initialItems);
  }

  Future<void> _createRental(Rental rental) async {
    await _rentalDao.insert(rental);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental ticket created');
    }
  }

  Future<void> _markRentalPickedUp(Rental rental) async {
    await _rentalDao.markPickedUp(rental.id!);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Marked as picked up');
    }
  }

  Future<void> _showConfirmReturnDialog(BuildContext context, Rental rental) async {
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm that ${rental.totalItemCount} units have been returned to ${rental.companyName}?',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Confirmation Notes (optional)',
                hintText: 'e.g., Returned to warehouse, received by John',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _rentalDao.markReturned(
                rental.id!,
                confirmation: notesController.text.trim().nullIfEmpty,
              );
              await _loadData();
              if (!mounted) return;
              this.context.read<AppStateProvider>().notifyRefreshNeeded();
              this.context.showSuccess('Return confirmed');
            },
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    notesController.dispose();
  }

  Future<void> _cancelRental(Rental rental) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Rental?'),
        content: Text(
          'Cancel rental from ${rental.companyName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Cancel Rental'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _rentalDao.cancel(rental.id!);
      await _loadData();
      if (mounted) {
        context.read<AppStateProvider>().notifyRefreshNeeded();
        context.showSuccess('Rental cancelled');
      }
    }
  }

  Future<void> _showEditEventDialog(BuildContext context) async {
    final nameController = TextEditingController(text: _event.name);
    final descController = TextEditingController(text: _event.description ?? '');
    final locationController = TextEditingController(text: _event.location ?? '');
    DateTime startDate = _event.startDate;
    DateTime endDate = _event.endDate;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Event'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Date'),
                      subtitle: Text(startDate.formattedWithTime),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startDate),
                          );
                          if (time != null) {
                            setDialogState(() {
                              startDate = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Date'),
                      subtitle: Text(endDate.formattedWithTime),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endDate),
                          );
                          if (time != null) {
                            setDialogState(() {
                              endDate = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final updated = _event.copyWith(
                    name: nameController.text.trim(),
                    description: descController.text.trim().nullIfEmpty,
                    location: locationController.text.trim().nullIfEmpty,
                    startDate: startDate,
                    endDate: endDate,
                  );
                  
                  Navigator.pop(dialogContext);
                  await _updateEvent(updated);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    descController.dispose();
    locationController.dispose();
  }

  Future<void> _updateEvent(Event event) async {
    final provider = context.read<EventProvider>();
    await provider.updateEvent(event);
    
    setState(() => _event = event);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Event updated');
    }
  }

  Future<void> _confirmDeleteEvent(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text(
          'Are you sure you want to delete "${_event.name}"?\n\n'
          'This will also remove all allocations and rental tickets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final provider = this.context.read<EventProvider>();
      await _rentalDao.deleteForEvent(_event.id!);
      await provider.deleteEvent(_event.id!);
      
      if (mounted) {
        Navigator.pop(this.context);
        this.context.showSuccess('Event deleted');
      }
    }
  }
}

/// Helper class to hold allocation with its item details
class AllocationWithItem {
  final Allocation allocation;
  final Item item;

  AllocationWithItem({required this.allocation, required this.item});
}
