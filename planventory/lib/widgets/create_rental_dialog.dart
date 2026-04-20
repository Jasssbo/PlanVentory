import 'package:flutter/material.dart';
import '../models/models.dart';
import '../extensions/extensions.dart';

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
  late List<RentalItemData> _items;

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
    _items = widget.initialItems.map((item) => RentalItemData(
      itemId: item.itemId,
      itemName: item.itemName,
      quantity: item.quantity,
    )).toList();
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
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to rent')),
      );
      return;
    }
    
    // Create RentalItem objects (rentalId will be set when saved)
    final rentalItems = _items.map((item) => RentalItem(
      rentalId: 0, // Will be set by DAO
      itemId: item.itemId,
      quantity: item.quantity,
      itemName: item.itemName,
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
    
    Navigator.pop(context, rental);
  }

  void _addItem() async {
    // Get items not already in the list
    final availableToAdd = widget.availableItems.where((item) =>
      !_items.any((ri) => ri.itemId == item.id)
    ).toList();
    
    if (availableToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more items available to add')),
      );
      return;
    }
    
    final result = await showDialog<RentalItemData>(
      context: context,
      builder: (context) => _AddItemDialog(availableItems: availableToAdd),
    );
    
    if (result != null && mounted) {
      setState(() => _items.add(result));
    }
  }
  
  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }
  
  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() => _items[index].quantity = newQuantity);
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
          onPressed: _submit,
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
  
  Widget _buildItemRow(RentalItemData item, int index, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: index > 0 ? BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ) : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.itemName,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          // Quantity controls
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: item.quantity > 1 
                ? () => _updateQuantity(index, item.quantity - 1)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${item.quantity}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _updateQuantity(index, item.quantity + 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
            onPressed: () => _removeItem(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }
}

/// Dialog to add an item to the rental
class _AddItemDialog extends StatefulWidget {
  final List<Item> availableItems;
  
  const _AddItemDialog({required this.availableItems});
  
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  Item? _selectedItem;
  int _quantity = 1;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Using 'value' for controlled dropdown (initialValue doesn't support dynamic updates)
            DropdownButtonFormField<Item>(
              // ignore: deprecated_member_use
              value: _selectedItem,
              decoration: const InputDecoration(
                labelText: 'Select Item',
                border: OutlineInputBorder(),
              ),
              items: widget.availableItems.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (item) {
                if (item != _selectedItem) {
                  setState(() => _selectedItem = item);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: '1',
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _quantity = int.tryParse(value) ?? 1,
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
          onPressed: _selectedItem != null ? () {
            Navigator.pop(context, RentalItemData(
              itemId: _selectedItem!.id!,
              itemName: _selectedItem!.name,
              quantity: _quantity > 0 ? _quantity : 1,
            ));
          } : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
