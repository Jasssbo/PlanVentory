import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import '../widgets/create_rental_dialog.dart';
import '../widgets/edit_rental_dialog.dart';
import 'inventory_screen.dart';

/// Simple result carrier for venue-picker dialogs.
class _VenuePick {
  final int? venueId;
  const _VenuePick({required this.venueId});
}

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
  List<Venue> _venues = [];
  int? _selectedVenueId; // null = "All Venues"
  bool _isLoading = true;
  bool _categoryView = false;

  final AllocationDao _allocationDao = AllocationDao();
  final ItemDao _itemDao = ItemDao();
  final RentalDao _rentalDao = RentalDao();
  final VenueDao _venueDao = VenueDao();
  final AvailabilityService _availabilityService = AvailabilityService();

  // Allocations/rentals filtered by the currently selected venue (or all if null).
  List<AllocationWithItem> get _visibleAllocations => _selectedVenueId == null
      ? _allocations
      : _allocations.where((a) => a.allocation.venueId == _selectedVenueId).toList();

  List<Rental> get _visibleRentals {
    if (_selectedVenueId == null) return _rentals;
    return _rentals.where((r) {
      // Rental directly tagged to this venue
      if (r.venueId == _selectedVenueId) return true;
      // Rental without a venue tag — include it if any of its items are
      // allocated to this venue (rental-only items linked by itemId)
      if (r.venueId != null) return false;
      return r.items.any((ri) => _allocations.any((a) =>
          a.item.id != null &&
          a.item.id == ri.itemId &&
          a.allocation.venueId == _selectedVenueId));
    }).toList();
  }

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

    // Load venues
    final venues = await _venueDao.getForEvent(_event.id!);

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
      _venues = venues;
      // Reset venue filter if the selected venue was deleted
      if (_selectedVenueId != null &&
          !venues.any((v) => v.id == _selectedVenueId)) {
        _selectedVenueId = null;
      }
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
                    const SizedBox(height: 16),
                    _buildVenueSelector(context),
                    const SizedBox(height: 16),
                    if (_shortages.isNotEmpty) ...[
                      _buildShortagesSection(context),
                      const SizedBox(height: 24),
                    ],
                    _buildMaterialsSection(context),
                    const SizedBox(height: 24),
                    if (_selectedVenueId == null &&
                        _visibleRentals.isNotEmpty) ...[
                      _buildRentalsSection(context),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedVenueId == null &&
                        (_visibleAllocations.isNotEmpty ||
                            _visibleRentals.isNotEmpty)) ...[
                      _buildSharedGearValueSection(context),
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

  // ─── Venue selector ────────────────────────────────────────────────────────

  Widget _buildVenueSelector(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: colorScheme.secondary),
            const SizedBox(width: 6),
            Text(
              'Venues / Stages',
              style: context.textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_venues.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 18),
                tooltip: 'Manage venues',
                onPressed: () => _showManageVenuesDialog(context),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_venues.isEmpty)
          // Empty state — prompt user to split the event into stages
          OutlinedButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Split event into stages / venues'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.secondary,
              side: BorderSide(
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                  style: BorderStyle.solid),
            ),
            onPressed: () => _showAddVenueDialog(context),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Venues'),
                    selected: _selectedVenueId == null,
                    onSelected: (_) => setState(() => _selectedVenueId = null),
                  ),
                ),
                // Per-venue chips
                ..._venues.map((v) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(v.name),
                        selected: _selectedVenueId == v.id,
                        onSelected: (_) =>
                            setState(() => _selectedVenueId = v.id),
                      ),
                    )),
                // Add venue chip
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add Venue'),
                  onPressed: () => _showAddVenueDialog(context),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showAddVenueDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Venue'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Venue name',
            hintText: 'e.g., Main Stage, Stage 2, Backstage',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      final id = await _venueDao.insert(Venue(
        eventId: _event.id!,
        name: result,
        sortOrder: _venues.length,
      ));
      await _loadData();
      if (mounted) setState(() => _selectedVenueId = id);
    }
  }

  Future<void> _showManageVenuesDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage Venues'),
            content: SizedBox(
              width: 380,
              child: _venues.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No venues yet. Add one below.'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _venues
                          .map((v) => ListTile(
                                leading: const Icon(Icons.place_outlined),
                                title: Text(v.name),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      tooltip: 'Rename',
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _showRenameVenueDialog(
                                            context, v);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 18,
                                          color: context.colorScheme.error),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _confirmDeleteVenue(context, v);
                                      },
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Venue'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddVenueDialog(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRenameVenueDialog(BuildContext context, Venue venue) async {
    final controller = TextEditingController(text: venue.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Venue'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Venue name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      await _venueDao.update(venue.copyWith(name: result));
      await _loadData();
    }
  }

  Future<void> _confirmDeleteVenue(BuildContext context, Venue venue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${venue.name}"?'),
        content: const Text(
            'Materials and rentals assigned to this venue will become unassigned '
            'but will NOT be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.error),
            child: const Text('Delete Venue'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _venueDao.unassignItemsForVenue(venue.id!);
      await _venueDao.delete(venue.id!);
      await _loadData();
    }
  }

  // ─── Shortages ─────────────────────────────────────────────────────────────

  Widget _buildShortagesSection(BuildContext context) {    return Column(
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
    final visible = _visibleAllocations;
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
              '${visible.length} items',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
            if (visible.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _categoryView ? Icons.list : Icons.category_outlined,
                  color: context.colorScheme.primary,
                ),
                tooltip: _categoryView ? 'List view' : 'Category view',
                onPressed: () => setState(() => _categoryView = !_categoryView),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
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
        else if (_categoryView)
          _buildCategoryGroupedView(context)
        else
          ...(visible.map((a) => _buildAllocationTile(context, a))),
      ],
    );
  }

  /// Returns the card background colour for an item in category view based on rental status.
  /// null = neutral (no override).
  Color? _categoryTileColor(AllocationWithItem a, ColorScheme cs) {
    final needsRental = a.item.isRentalOnly ||
        a.allocation.quantityNeeded > a.item.quantity;
    if (!needsRental) return null;

    final itemRentals = _rentals
        .where((r) =>
            r.status != RentalStatus.cancelled &&
            r.items.any((ri) => ri.itemId == a.item.id))
        .toList();

    if (itemRentals.isEmpty) return cs.errorContainer;
    if (itemRentals.any((r) => r.status == RentalStatus.returned)) return null;
    if (itemRentals.any((r) => r.status == RentalStatus.pickedUp)) {
      return Colors.green.withValues(alpha: 0.18);
    }
    // pending
    return Colors.amber.withValues(alpha: 0.25);
  }

  Widget _buildCategoryViewTile(
      BuildContext context, AllocationWithItem allocation) {
    final colorScheme = context.colorScheme;
    final isRentalOnly = allocation.item.isRentalOnly;
    final tileColor = _categoryTileColor(allocation, colorScheme);

    final leading = CircleAvatar(
      backgroundColor: isRentalOnly
          ? colorScheme.tertiaryContainer
          : colorScheme.primaryContainer,
      child: Icon(
        isRentalOnly ? Icons.shopping_cart : Icons.category,
        color: isRentalOnly
            ? colorScheme.onTertiaryContainer
            : colorScheme.primary,
        size: 20,
      ),
    );

    final quantityBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${allocation.allocation.quantityNeeded}',
        style: context.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    final subtitle = _buildCategoryTileSubtitle(context, allocation);

    if (_venues.isNotEmpty) {
      return Card(
        color: tileColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      allocation.item.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    ?subtitle,
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      quantityBadge,
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: colorScheme.primary, size: 20),
                        onPressed: () =>
                            _showEditAllocationDialog(context, allocation),
                        tooltip: 'Edit quantity',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.swap_horiz,
                            color: colorScheme.secondary, size: 20),
                        onPressed: () =>
                            _showMoveAllocationDialog(context, allocation),
                        tooltip: 'Move to venue',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: colorScheme.error, size: 20),
                        onPressed: () =>
                            _confirmRemoveAllocation(context, allocation),
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: tileColor,
      child: ListTile(
        leading: leading,
        title: Text(allocation.item.name),
        subtitle: subtitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            quantityBadge,
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.primary, size: 20),
              onPressed: () =>
                  _showEditAllocationDialog(context, allocation),
              tooltip: 'Edit quantity',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: colorScheme.error, size: 20),
              onPressed: () => _confirmRemoveAllocation(context, allocation),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildCategoryTileSubtitle(
      BuildContext context, AllocationWithItem a) {
    if (!a.item.isRentalOnly &&
        a.allocation.quantityNeeded <= a.item.quantity) {
      return null; // owned item with enough stock — no status needed
    }
    final itemRentals = _rentals
        .where((r) =>
            r.status != RentalStatus.cancelled &&
            r.items.any((ri) => ri.itemId == a.item.id))
        .toList();

    String statusLabel;
    if (itemRentals.isEmpty) {
      statusLabel = 'No rental arranged';
    } else if (itemRentals.any((r) => r.status == RentalStatus.returned)) {
      statusLabel = 'Returned';
    } else if (itemRentals.any((r) => r.status == RentalStatus.pickedUp)) {
      statusLabel = 'Picked up — in use';
    } else {
      statusLabel = 'Rental pending';
    }

    return Text(
      statusLabel,
      style: TextStyle(color: context.colorScheme.outline),
    );
  }

  Widget _buildCategoryGroupedView(BuildContext context) {
    final colorScheme = context.colorScheme;
    final allocations = _visibleAllocations;

    // Group ALL allocations by category (null → 'Uncategorized')
    final Map<String, List<AllocationWithItem>> grouped = {};
    for (final a in allocations) {
      final key = (a.item.category?.isNotEmpty == true)
          ? a.item.category!
          : 'Uncategorized';
      grouped.putIfAbsent(key, () => []).add(a);
    }

    // Sort categories alphabetically, 'Uncategorized' last
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Uncategorized') return 1;
        if (b == 'Uncategorized') return -1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in sortedKeys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 16, color: colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  category,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${grouped[category]!.length})',
                  style: context.textTheme.labelSmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          ...grouped[category]!
              .map((a) => _buildCategoryViewTile(context, a)),
        ],
      ],
    );
  }

  /// Builds the per-venue cost breakdown row (inventory items + rental items
  /// allocated to that venue). Extracted from the Builder-in-for-loop pattern
  /// to avoid the build-scope assertion error.
  Widget _buildVenueValueRow(BuildContext context, Venue venue) {
    final colorScheme = context.colorScheme;

    final vAllocs = _allocations
        .where((a) => a.allocation.venueId == venue.id)
        .toList();
    final vValuedAllocs = vAllocs
        .where((a) =>
            !a.item.isRentalOnly &&
            a.item.unitCost != null &&
            a.item.unitCost! > 0)
        .toList();

    // Build map: rental → rental items allocated to THIS venue with a cost.
    // One rental may have items spread across venues — we only count items
    // whose inventory allocation points to this venue.
    final Map<Rental, List<RentalItem>> vRentalByCompany = {};
    for (final rental in _rentals.where(
        (r) => r.status != RentalStatus.cancelled)) {
      for (final ri in rental.items) {
        if (ri.itemCost == null || ri.itemCost! <= 0) continue;
        final isInVenue = _allocations.any((a) =>
            a.item.id != null &&
            a.item.id == ri.itemId &&
            a.allocation.venueId == venue.id);
        if (isInVenue) {
          vRentalByCompany.putIfAbsent(rental, () => []).add(ri);
        }
      }
    }

    final vInv = vValuedAllocs.fold<double>(
        0, (s, a) => s + a.item.unitCost! * a.allocation.quantityNeeded);
    final vRent = vRentalByCompany.values.fold<double>(
        0,
        (s, items) =>
            s + items.fold<double>(0, (ss, ri) => ss + ri.itemCost! * ri.quantity));
    final vTotal = vInv + vRent;

    if (vTotal == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Venue header row
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: colorScheme.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  venue.name,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              Text(
                '€${vTotal.toStringAsFixed(2)}',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        // Owned inventory items with cost
        for (final a in vValuedAllocs)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right,
                    size: 14, color: colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${a.item.name} × ${a.allocation.quantityNeeded}',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ),
                Text(
                  '€${(a.item.unitCost! * a.allocation.quantityNeeded).toStringAsFixed(2)}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        // Rental items grouped by company — only items allocated to this venue
        for (final entry in vRentalByCompany.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 14, color: colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.key.companyName,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Text(
                  '€${entry.value.fold<double>(0, (s, ri) => s + ri.itemCost! * ri.quantity).toStringAsFixed(2)}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          for (final ri in entry.value)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      size: 12, color: colorScheme.outlineVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${ri.itemName ?? 'Item #${ri.itemId}'} × ${ri.quantity}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outlineVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    '€${(ri.itemCost! * ri.quantity).toStringAsFixed(2)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outlineVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCategoryValueSummary(
      BuildContext context, double inventoryValue, double rentalValue,
      {bool showVenueBreakdown = false}) {
    final colorScheme = context.colorScheme;
    final total = inventoryValue + rentalValue;

    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.euro, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  'Total Gear Value',
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (inventoryValue > 0) ...[
              _summaryRow(context, 'Owned inventory',
                  '€${inventoryValue.toStringAsFixed(2)}'),
              // Per-item breakdown (informational — part of the owned inventory total above)
              for (final a in _visibleAllocations.where((a) =>
                  !a.item.isRentalOnly &&
                  a.item.unitCost != null &&
                  a.item.unitCost! > 0))
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.subdirectory_arrow_right,
                          size: 14, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${a.item.name} × ${a.allocation.quantityNeeded}',
                          style: context.textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ),
                      Text(
                        '€${(a.item.unitCost! * a.allocation.quantityNeeded).toStringAsFixed(2)}',
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
            ],
            if (rentalValue > 0) ...[
              _summaryRow(
                  context, 'Rental costs', '€${rentalValue.toStringAsFixed(2)}'),
              // Per-item cost breakdown (informational — part of the rental total above)
              for (final rental in _visibleRentals.where(
                  (r) => r.status != RentalStatus.cancelled))
                for (final item in rental.items.where(
                    (i) => i.itemCost != null && i.itemCost! > 0))
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 14, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.itemName ?? 'Item #${item.itemId}'} × ${item.quantity}',
                            style: context.textTheme.bodySmall
                                ?.copyWith(color: colorScheme.outline),
                          ),
                        ),
                        Text(
                          '€${item.itemCost!.toStringAsFixed(2)}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
            // Per-venue breakdown in "All Venues" view
            if (showVenueBreakdown) ...[
              const Divider(height: 20),
              Text(
                'Per Venue',
                style: context.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.outline),
              ),
              const SizedBox(height: 6),
              for (final venue in _venues)
                _buildVenueValueRow(context, venue),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Grand Total',
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: context.colorScheme.outline),
            ),
          ),
          Text(value, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAllocationTile(BuildContext context, AllocationWithItem allocation) {
    final colorScheme = context.colorScheme;
    final isShortage = _shortages.any((s) => s.itemId == allocation.item.id);
    final isRentalOnly = allocation.item.isRentalOnly;
    final cardColor = isShortage
        ? colorScheme.errorContainer.withValues(alpha: 0.2)
        : null;

    final leading = CircleAvatar(
      backgroundColor: isShortage
          ? colorScheme.error.withValues(alpha: 0.2)
          : isRentalOnly
              ? colorScheme.tertiaryContainer
              : colorScheme.primaryContainer,
      child: Icon(
        isRentalOnly ? Icons.shopping_cart : Icons.category,
        color: isShortage
            ? colorScheme.error
            : isRentalOnly
                ? colorScheme.onTertiaryContainer
                : colorScheme.primary,
      ),
    );

    final quantityBadge = Container(
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
    );

    if (_venues.isNotEmpty) {
      return Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      allocation.item.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      allocation.item.category ?? 'No category',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      quantityBadge,
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.edit, color: colorScheme.primary),
                        onPressed: () =>
                            _showEditAllocationDialog(context, allocation),
                        tooltip: 'Edit quantity',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.swap_horiz,
                            color: colorScheme.secondary),
                        onPressed: () =>
                            _showMoveAllocationDialog(context, allocation),
                        tooltip: 'Move to venue',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: colorScheme.error),
                        onPressed: () =>
                            _confirmRemoveAllocation(context, allocation),
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: cardColor,
      child: ListTile(
        leading: leading,
        title: Text(allocation.item.name),
        subtitle: Text(
          allocation.item.category ?? 'No category',
          style: TextStyle(color: colorScheme.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            quantityBadge,
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

  /// Unified gear value display used by both list and category views.
  /// Uses the same card style as [_buildCategoryValueSummary].
  Widget _buildSharedGearValueSection(BuildContext context) {
    final allocations = _visibleAllocations;
    final rentals = _visibleRentals;

    final inventoryValue = allocations
        .where((a) =>
            !a.item.isRentalOnly &&
            a.item.unitCost != null &&
            a.item.unitCost! > 0)
        .fold<double>(
            0, (s, a) => s + a.item.unitCost! * a.allocation.quantityNeeded);

    double rentalEffectiveCost(Rental r) {
      if (r.rentalCost != null) return r.rentalCost!;
      return r.items
          .fold<double>(0, (s, i) => s + (i.itemCost ?? 0) * i.quantity);
    }

    final rentalValue = rentals
        .where((r) => r.status != RentalStatus.cancelled)
        .fold<double>(0, (s, r) => s + rentalEffectiveCost(r));

    if (inventoryValue == 0 && rentalValue == 0) return const SizedBox.shrink();

    final showVenueBreakdown = _selectedVenueId == null && _venues.isNotEmpty;

    return _buildCategoryValueSummary(
      context,
      inventoryValue,
      rentalValue,
      showVenueBreakdown: showVenueBreakdown,
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
        ...(_visibleRentals.map((r) => _buildRentalTile(context, r))),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') _editRental(rental);
                    if (value == 'move') _showMoveRentalDialog(context, rental);
                    if (value == 'delete') _deleteRental(rental);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_venues.isNotEmpty)
                      const PopupMenuItem(
                        value: 'move',
                        child: ListTile(
                          leading: Icon(Icons.swap_horiz),
                          title: Text('Move to venue'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
            // Show items in the rental with per-item cost if available
            ...rental.items.map((item) {
              final hasItemCost = item.itemCost != null && item.itemCost! > 0;
              return Padding(
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
                    if (hasItemCost)
                      Text(
                        '€${item.itemCost!.toStringAsFixed(2)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              );
            }),
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
    // Pre-select the active venue (null = no specific venue / all)
    int? selectedVenueId = _selectedVenueId;
    final newItemNameController = TextEditingController();
    final newItemCategoryController = TextEditingController();

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
                      controller: newItemCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g., Audio, Video, Lighting',
                        border: OutlineInputBorder(),
                      ),
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
                  // Venue picker — shown only when venues exist
                  if (_venues.isNotEmpty) ...[
                    const Divider(height: 24),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Venue / Stage',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      initialValue: selectedVenueId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No specific venue'),
                        ),
                        ..._venues.map((v) => DropdownMenuItem<int?>(
                              value: v.id,
                              child: Text(v.name),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => selectedVenueId = v),
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
                          await _addMaterial(selectedItem!, quantity,
                              venueId: selectedVenueId);
                        } else if (selectedTab == 1) {
                          await _addRentalOnlyMaterial(
                            newItemNameController.text.trim(),
                            quantity,
                            category: newItemCategoryController.text.trim().nullIfEmpty,
                            venueId: selectedVenueId,
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
    newItemCategoryController.dispose();
  }

  Future<void> _addRentalOnlyMaterial(String itemName, int quantity,
      {String? category, int? venueId}) async {
    // Create a new rental-only item in inventory
    final newItem = Item(
      name: itemName,
      quantity: 0, // We don't own any
      isRentalOnly: true,
      category: category ?? 'Rental Only',
    );
    
    final itemDao = ItemDao();
    final itemId = await itemDao.insert(newItem);
    
    // Create allocation for this event
    final allocation = Allocation(
      eventId: _event.id!,
      itemId: itemId,
      quantityNeeded: quantity,
      venueId: venueId,
    );

    await _allocationDao.insert(allocation);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental-only material added');
    }
  }

  Future<void> _addMaterial(Item item, int quantity, {int? venueId}) async {
    final allocation = Allocation(
      eventId: _event.id!,
      itemId: item.id!,
      quantityNeeded: quantity,
      venueId: venueId,
    );

    await _allocationDao.insert(allocation);
    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Material added');
    }
  }

  // ─── Move to venue ─────────────────────────────────────────────────────────

  Future<void> _showMoveAllocationDialog(
      BuildContext context, AllocationWithItem allocation) async {
    final currentVenueId = allocation.allocation.venueId;
    final currentVenueName = currentVenueId == null
        ? 'No specific venue'
        : (_venues.firstWhere((v) => v.id == currentVenueId,
                orElse: () => _venues.first))
            .name;

    final picked = await showDialog<_VenuePick>(
      context: context,
      builder: (ctx) {
        int? selected = currentVenueId;
        return StatefulBuilder(
          builder: (context, setS) => AlertDialog(
            title: Text('Move "${allocation.item.name}"'),
            content: RadioGroup<int?>(
              groupValue: selected,
              onChanged: (v) => setS(() => selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current: $currentVenueName',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: context.colorScheme.outline),
                  ),
                  const Divider(height: 16),
                  const RadioListTile<int?>(
                    value: null,
                    title: Text('No specific venue'),
                  ),
                  ..._venues.map((v) => RadioListTile<int?>(
                        value: v.id,
                        title: Text(v.name),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, _VenuePick(venueId: selected)),
                child: const Text('Move'),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      final updated = allocation.allocation.copyWith(
        venueId: picked.venueId,
        clearVenueId: picked.venueId == null,
      );
      await _allocationDao.update(updated);
      await _loadData();
    }
  }

  Future<void> _showMoveRentalDialog(
      BuildContext context, Rental rental) async {
    final currentVenueId = rental.venueId;
    final currentVenueName = currentVenueId == null
        ? 'No specific venue'
        : (_venues.firstWhere((v) => v.id == currentVenueId,
                orElse: () => _venues.first))
            .name;

    final picked = await showDialog<_VenuePick>(
      context: context,
      builder: (ctx) {
        int? selected = currentVenueId;
        return StatefulBuilder(
          builder: (context, setS) => AlertDialog(
            title: const Text('Move rental to venue'),
            content: RadioGroup<int?>(
              groupValue: selected,
              onChanged: (v) => setS(() => selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current: $currentVenueName',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: context.colorScheme.outline),
                  ),
                  const Divider(height: 16),
                  const RadioListTile<int?>(
                    value: null,
                    title: Text('No specific venue'),
                  ),
                  ..._venues.map((v) => RadioListTile<int?>(
                        value: v.id,
                        title: Text(v.name),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, _VenuePick(venueId: selected)),
                child: const Text('Move'),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      final updated = rental.copyWith(
        venueId: picked.venueId,
        clearVenueId: picked.venueId == null,
      );
      await _rentalDao.update(updated);
      await _loadData();
    }
  }

  Future<void> _showEditAllocationDialog(
      BuildContext context, AllocationWithItem allocation) async {
    // For rental-only items, item.quantity is always 0 (not owned).
    // Show the allocation's quantityNeeded as the initial quantity instead.
    final itemForEdit = allocation.item.isRentalOnly
        ? allocation.item.copyWith(
            quantity: allocation.allocation.quantityNeeded)
        : allocation.item;
    final oldQty = itemForEdit.quantity;
    await showDialog(
      context: context,
      builder: (dialogContext) => AddItemDialog(item: itemForEdit),
    );
    if (!mounted) return;
    // Re-fetch the item to check if quantity changed
    final updatedItem = await _itemDao.getById(allocation.item.id!);
    if (!mounted) return;
    if (updatedItem != null) {
      // For rental-only: quantity in DB stays 0; use updatedItem.quantity only
      // if the user changed it, otherwise preserve allocation qty.
      final newQty = allocation.item.isRentalOnly
          ? updatedItem.quantity == 0 ? allocation.allocation.quantityNeeded : updatedItem.quantity
          : updatedItem.quantity;
      if (newQty != allocation.allocation.quantityNeeded ||
          (!allocation.item.isRentalOnly && updatedItem.quantity != oldQty)) {
        // Sync allocation quantityNeeded
        await _allocationDao.update(
            allocation.allocation.copyWith(quantityNeeded: newQty));
        // Sync rental item quantities for this event
        for (final rental in _rentals) {
          for (final ri in rental.items) {
            if (ri.itemId == allocation.item.id) {
              final updatedRental = rental.copyWith(
                items: rental.items
                    .map((i) => i.itemId == allocation.item.id
                        ? i.copyWith(quantity: newQty)
                        : i)
                    .toList(),
              );
              await _rentalDao.update(updatedRental);
              break;
            }
          }
        }
      }
    }
    await _loadData();
    if (!mounted) return;
    this.context.read<AppStateProvider>().notifyRefreshNeeded();
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
    // If venues exist and no specific venue is pre-selected, let the user pick one first
    int? rentalVenueId = _selectedVenueId;
    if (_venues.isNotEmpty && rentalVenueId == null) {
      rentalVenueId = await showDialog<int?>(
        context: context,
        builder: (ctx) {
          int? picked; // null = no specific venue
          return AlertDialog(
            title: const Text('Assign to Venue?'),
            content: StatefulBuilder(
              builder: (context, setState) => RadioGroup<int?>(
                groupValue: picked,
                onChanged: (v) => setState(() => picked = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<int?>(
                      title: Text('No specific venue'),
                      value: null,
                    ),
                    ..._venues.map((v) => RadioListTile<int?>(
                          title: Text(v.name),
                          value: v.id,
                        )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, picked),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
    }

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
      await _createRental(result, venueId: rentalVenueId);
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

  Future<void> _createRental(Rental rental, {int? venueId}) async {
    // Attach venue if one is active
    final toSave = venueId != null ? rental.copyWith(venueId: venueId) : rental;
    await _rentalDao.insert(toSave);

    // Ensure every item in the rental has an allocation for this event.
    // The item that triggered the dialog already has one; items added *inside*
    // the rental dialog do not, so we create them here.
    for (final ri in rental.items) {
      final existing =
          await _allocationDao.getByEventAndItem(_event.id!, ri.itemId);
      if (existing == null) {
        await _allocationDao.insert(Allocation(
          eventId: _event.id!,
          itemId: ri.itemId,
          quantityNeeded: ri.quantity,
        ));
      }
    }

    await _loadData();
    
    if (mounted) {
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental ticket created');
    }
  }

  Future<void> _editRental(Rental rental) async {
    final availableItems = await _itemDao.getAll();
    if (!mounted) return;

    final updatedRental = await showDialog<Rental>(
      context: context,
      builder: (dialogContext) => EditRentalDialog(
        rental: rental,
        availableItems: availableItems,
      ),
    );

    if (updatedRental != null && mounted) {
      await _rentalDao.update(updatedRental);
      await _loadData();
      if (!mounted) return;
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental updated');
    }
  }

  Future<void> _deleteRental(Rental rental) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rental?'),
        content: Text(
            'Delete rental from "${rental.companyName}"?\n\nThis action cannot be undone.'),
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

    if (confirmed == true && mounted) {
      await _rentalDao.delete(rental.id!);
      await _loadData();
      if (!mounted) return;
      context.read<AppStateProvider>().notifyRefreshNeeded();
      context.showSuccess('Rental deleted');
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
