import 'package:flutter/material.dart';
import '../models/models.dart';

/// Tile widget to display an inventory item
class ItemTile extends StatelessWidget {
  final Item item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final int? allocatedQuantity;

  const ItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.allocatedQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: item.isRentalOnly 
              ? colorScheme.tertiaryContainer 
              : colorScheme.primaryContainer,
          child: item.isRentalOnly
              ? Icon(
                  Icons.shopping_cart,
                  color: colorScheme.onTertiaryContainer,
                  size: 20,
                )
              : Text(
                  item.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.isRentalOnly) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RENTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: _buildSubtitle(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuantityBadge(context),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: onDelete,
                tooltip: 'Delete item',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (item.category != null) parts.add(item.category!);
    if (!item.isRentalOnly && item.unitCost != null) {
      parts.add('€${item.unitCost!.toStringAsFixed(2)}/unit');
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: TextStyle(color: colorScheme.outline),
    );
  }

  Widget _buildQuantityBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Rental-only items show a special badge
    if (item.isRentalOnly) {
      if (allocatedQuantity != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart,
                size: 16,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                'Need $allocatedQuantity',
                style: TextStyle(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 16,
              color: colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Rent only',
              style: TextStyle(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    if (allocatedQuantity != null) {
      final isOverAllocated = allocatedQuantity! > item.quantity;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isOverAllocated 
              ? colorScheme.errorContainer 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2,
              size: 16,
              color: isOverAllocated 
                  ? colorScheme.onErrorContainer 
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$allocatedQuantity / ${item.quantity}',
              style: TextStyle(
                color: isOverAllocated 
                    ? colorScheme.onErrorContainer 
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '×${item.quantity}',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
