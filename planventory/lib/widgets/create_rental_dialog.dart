import 'package:flutter/material.dart';
import '../models/models.dart';
import '../extensions/extensions.dart';
import '../services/services.dart';

/// Represents an item in the rental list — itemId is null for brand-new items
/// that haven't been persisted to the DB yet.
class _PendingRentalItem {
  int? itemId;
  final String itemName;
  final String? category;
  int quantity;
  double? itemCost;

  _PendingRentalItem({
    this.itemId,
    required this.itemName,
    this.category,
    required this.quantity,
  });
}

/// Dialog widget for creating a rental with multiple items
class CreateRentalDialog extends StatefulWidget {
  final Event event;
  /// Initial items to include (e.g., from shortages)
  final List<RentalItemData> initialItems;
  /// All available items the user can add to the rental
  final List<Item> availableItems;

  const CreateRentalDialog({
    super.key,
    required this.event,
    this.initialItems = const [],
    this.availableItems = const [],
  });

  @override
  State<CreateRentalDialog> createState() => _CreateRentalDialogState();
}

class _CreateRentalDialogState extends State<CreateRentalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyController;
  late final TextEditingController _contactController;
  late final TextEditingController _costController;
  late final TextEditingController _pickupLocationController;
  late final TextEditingController _returnLocationController;
  late final TextEditingController _pickupNotesController;
  late final TextEditingController _returnNotesController;
  
  late DateTime _pickupDate;
  late DateTime _returnDate;
  final String _currency = 'EUR';
  
  // Items to rent
  late List<_PendingRentalItem> _items;
  // Per-item cost controllers (parallel list)
  final List<TextEditingController> _itemCostControllers = [];

  final ItemDao _itemDao = ItemDao();

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController();
    _contactController = TextEditingController();
    _costController = TextEditingController();
    _pickupLocationController = TextEditingController();
    _returnLocationController = TextEditingController();
    _pickupNotesController = TextEditingController();
    _returnNotesController = TextEditingController();
    
    _pickupDate = widget.event.startDate.subtract(const Duration(days: 1));
    _returnDate = widget.event.endDate.add(const Duration(days: 1));
    
    // Copy initial items so we can modify them
    _items = widget.initialItems.map((item) => _PendingRentalItem(
      itemId: item.itemId,
      itemName: item.itemName,
      quantity: item.quantity,
    )).toList();
    // Initialise cost controllers for pre-filled items
    for (final _ in _items) {
      _itemCostControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _costController.dispose();
    _pickupLocationController.dispose();
    _returnLocationController.dispose();
    _pickupNotesController.dispose();
    _returnNotesController.dispose();
    for (final c in _itemCostControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to rent')),
      );
      return;
    }

    // Persist any brand-new items (itemId == null) before building the rental
    for (final pending in _items) {
      if (pending.itemId == null) {
        final newItem = Item(
          name: pending.itemName,
          quantity: 0,
          isRentalOnly: true,
          category: pending.category?.trim().isNotEmpty == true
              ? pending.category
              : 'Rental Only',
        );
        pending.itemId = await _itemDao.insert(newItem);
      }
    }
    
    // Create RentalItem objects (rentalId will be set when saved)
    final rentalItems = _items.asMap().entries.map((e) => RentalItem(
      rentalId: 0, // Will be set by DAO
      itemId: e.value.itemId!,
      quantity: e.value.quantity,
      itemName: e.value.itemName,
      itemCost: e.value.itemCost,
    )).toList();
    
    final rental = Rental(
      eventId: widget.event.id!,
      items: rentalItems,
      companyName: _companyController.text.trim(),
      companyContact: _contactController.text.trim().nullIfEmpty,
      rentalCost: double.tryParse(_costController.text),
      currency: _currency,
      pickupDate: _pickupDate,
      pickupLocation: _pickupLocationController.text.trim().nullIfEmpty,
      pickupNotes: _pickupNotesController.text.trim().nullIfEmpty,
      returnDate: _returnDate,
      returnLocation: _returnLocationController.text.trim().nullIfEmpty,
      returnNotes: _returnNotesController.text.trim().nullIfEmpty,
    );
    
    if (mounted) Navigator.pop(context, rental);
  }

  void _addItem() async {
    // Get items not already in the list
    final availableToAdd = widget.availableItems.where((item) =>
      !_items.any((ri) => ri.itemId == item.id)
    ).toList();
    
    final result = await showDialog<_PendingRentalItem>(
      context: context,
      builder: (context) => _AddItemDialog(availableItems: availableToAdd),
    );
    
    if (result != null && mounted) {
      setState(() {
        _items.add(result);
        _itemCostControllers.add(TextEditingController());
      });
    }
  }
  
  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _itemCostControllers[index].dispose();
      _itemCostControllers.removeAt(index);
    });
    _recomputeTotalIfAllItemsHaveCost();
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() => _items[index].quantity = newQuantity);
    }
  }

  void _updateItemCost(int index, String raw) {
    _items[index].itemCost = double.tryParse(raw.replaceAll(',', '.'));
    _recomputeTotalIfAllItemsHaveCost();
  }

  /// When every item has a cost, auto-fill the total from their sum —
  /// but only if the user has not already typed a total manually.
  void _recomputeTotalIfAllItemsHaveCost() {
    // Don't overwrite a total the user has already provided
    if (_costController.text.isNotEmpty) return;
    if (_items.isEmpty) return;
    final allHaveCost =
        _items.every((i) => i.itemCost != null && i.itemCost! > 0);
    if (allHaveCost) {
      final sum = _items.fold<double>(0, (s, i) => s + i.itemCost!);
      _costController.text = sum.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Create Rental'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a rental ticket to track materials borrowed from another company.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Items section
                _buildItemsSection(theme),
                const SizedBox(height: 16),
                
                const Divider(),
                const SizedBox(height: 16),
                
                // Company info
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact (phone/email)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Cost
                TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText: 'Total Rental Cost',
                    border: const OutlineInputBorder(),
                    prefixText: '$_currency ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // Pickup details
                Text(
                  'Pickup Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pickup Date'),
                  subtitle: Text(_pickupDate.formattedWithTime),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _pickupDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null && mounted) {
                      setState(() => _pickupDate = date);
                    }
                  },
                ),
                TextFormField(
                  controller: _pickupLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pickupNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Return details
                Text(
                  'Return Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Return Date'),
                  subtitle: Text(_returnDate.formattedWithTime),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _returnDate,
                      firstDate: _pickupDate,
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null && mounted) {
                      setState(() => _returnDate = date);
                    }
                  },
                ),
                TextFormField(
                  controller: _returnLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Return Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _returnNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Return Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(),
          child: const Text('Create Rental'),
        ),
      ],
    );
  }
  
  Widget _buildItemsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items to Rent',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No items selected. Click "Add Item" to add materials.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _items.length; i++)
                  _buildItemRow(_items[i], i, theme),
              ],
            ),
          ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Total: ${_items.length} item${_items.length > 1 ? 's' : ''} '
              '(${_items.fold(0, (sum, item) => sum + item.quantity)} units)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildItemRow(_PendingRentalItem item, int index, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: index > 0 ? BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: name + remove
          Row(
            children: [
              Expanded(
                child: Text(item.itemName, style: theme.textTheme.bodyMedium),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Remove item',
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: qty controls + optional cost
          Row(
            children: [
              // Quantity
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: item.quantity > 1
                    ? () => _updateQuantity(index, item.quantity - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.quantity}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _updateQuantity(index, item.quantity + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 12),
              // Per-item cost (optional)
              Expanded(
                child: TextField(
                  controller: _itemCostControllers[index],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Cost',
                    prefixText: '€ ',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    suffixIcon: _itemCostControllers[index].text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () {
                              _itemCostControllers[index].clear();
                              _updateItemCost(index, '');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          )
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (v) => _updateItemCost(index, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog to add an item to the rental.
/// Offers two tabs: pick from inventory or type a brand-new item name.
class _AddItemDialog extends StatefulWidget {
  final List<Item> availableItems;

  const _AddItemDialog({required this.availableItems});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  int _tab = 0; // 0 = from inventory, 1 = new item

  // Tab 0
  Item? _selectedItem;

  // Tab 1
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  int _quantity = 1;
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  @override
  void dispose() {
    _newNameController.dispose();
    _newCategoryController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_tab == 0) return _selectedItem != null;
    return _newNameController.text.trim().isNotEmpty;
  }

  void _confirm() {
    final qty = _quantity > 0 ? _quantity : 1;
    if (_tab == 0 && _selectedItem != null) {
      Navigator.pop(
        context,
        _PendingRentalItem(
          itemId: _selectedItem!.id!,
          itemName: _selectedItem!.name,
          quantity: qty,
        ),
      );
    } else if (_tab == 1) {
      final name = _newNameController.text.trim();
      if (name.isEmpty) return;
      Navigator.pop(
        context,
        _PendingRentalItem(
          itemId: null, // will be created on submit
          itemName: name,
          category: _newCategoryController.text.trim().nullIfEmpty,
          quantity: qty,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Item to Rental'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('From Inventory'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('New Item'),
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() {
                _tab = s.first;
                _quantity = 1;
                _quantityController.text = '1';
              }),
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...
              _buildFromInventory(theme)
            else ...
              _buildNewItem(theme),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => _quantity = int.tryParse(v) ?? 1),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  List<Widget> _buildFromInventory(ThemeData theme) {
    if (widget.availableItems.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'All inventory items are already in this rental. '  
            'Switch to "New Item" to add a custom one.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ];
    }
    return [
      DropdownButtonFormField<Item>(
        // ignore: deprecated_member_use
        value: _selectedItem,
        decoration: const InputDecoration(
          labelText: 'Select Item',
          border: OutlineInputBorder(),
        ),
        items: widget.availableItems
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (item) => setState(() => _selectedItem = item),
      ),
    ];
  }

  List<Widget> _buildNewItem(ThemeData theme) {
    return [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 16, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A new rental-only item will be created automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _newNameController,
        decoration: const InputDecoration(
          labelText: 'Item Name',
          hintText: 'e.g., Yamaha MG16 Mixer',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _newCategoryController,
        decoration: const InputDecoration(
          labelText: 'Category',
          hintText: 'e.g., Audio, Video, Lighting',
          border: OutlineInputBorder(),
        ),
      ),
    ];
  }
}
