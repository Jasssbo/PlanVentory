import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';

/// List of all inventory items
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _selectedCategory;
  final String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.items.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildCategoryFilter(context, provider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => context.read<AppStateProvider>().refreshAll(),
                  child: _buildItemsList(context, provider),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No items in inventory',
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first item to get started',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddItemDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, InventoryProvider provider) {
    if (provider.categories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: Spacing.horizontalMd,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ...provider.categories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, InventoryProvider provider) {
    var items = provider.items;

    // Filter by category
    if (_selectedCategory != null) {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items match your filters',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemTile(
          item: item,
          onTap: () => _showEditItemDialog(context, item),
          onDelete: () => _confirmDelete(context, item),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Item item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
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

    if (result == true && mounted) {
      final provider = this.context.read<InventoryProvider>();
      final warnings = await provider.deleteItem(item.id!);
      if (mounted) {
        this.context.read<AppStateProvider>().notifyRefreshNeeded();
      }
      if (warnings.isNotEmpty && mounted) {
        // Show warnings about affected events
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(warnings.first.message),
            backgroundColor: Theme.of(this.context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ItemSearchDelegate(
        items: context.read<InventoryProvider>().items,
        onSelected: (item) => _showEditItemDialog(context, item),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddItemDialog(),
    );
  }

  void _showEditItemDialog(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }
}

/// Dialog to add/edit an inventory item
class AddItemDialog extends StatefulWidget {
  final Item? item;

  const AddItemDialog({super.key, this.item});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _categoryController;
  bool _isSaving = false;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _descriptionController = TextEditingController(text: widget.item?.description);
    _quantityController =
        TextEditingController(text: '${widget.item?.quantity ?? 1}');
    _categoryController = TextEditingController(text: widget.item?.category);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<InventoryProvider>().categories;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Item' : 'New Item'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g., Round Table',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional details',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final qty = int.tryParse(value ?? '');
                    if (qty == null || qty < 1) {
                      return 'Enter a valid quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _categoryController.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return categories;
                    }
                    return categories.where((c) =>
                        c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    _categoryController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync with our controller
                    controller.text = _categoryController.text;
                    controller.addListener(() {
                      _categoryController.text = controller.text;
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g., Furniture',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveItem,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final item = Item(
      id: widget.item?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().nullIfEmpty,
      quantity: int.parse(_quantityController.text),
      category: _categoryController.text.trim().nullIfEmpty,
      createdAt: widget.item?.createdAt,
    );

    final provider = context.read<InventoryProvider>();
    List<InventoryWarning> warnings;

    if (isEditing) {
      warnings = await provider.updateItem(item);
    } else {
      warnings = await provider.addItem(item);
    }

    if (mounted) {
      Navigator.pop(context);
      context.read<AppStateProvider>().notifyRefreshNeeded();
      if (warnings.isNotEmpty) {
        // Show warning about affected events
        context.showSnackBar(warnings.first.message);
      } else {
        context.showSuccess(isEditing ? 'Item updated' : 'Item created');
      }
    }
  }
}

/// Search delegate for items
class _ItemSearchDelegate extends SearchDelegate<Item?> {
  final List<Item> items;
  final Function(Item) onSelected;

  _ItemSearchDelegate({required this.items, required this.onSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final filtered = items
        .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ItemTile(
          item: item,
          onTap: () {
            close(context, item);
            onSelected(item);
          },
        );
      },
    );
  }
}
