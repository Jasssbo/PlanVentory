import 'package:flutter/material.dart';
import '../models/models.dart';

/// Banner widget to display inventory warnings
class WarningBanner extends StatelessWidget {
  final InventoryWarning warning;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const WarningBanner({
    super.key,
    required this.warning,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: _getBackgroundColor(),
      leading: Icon(_getIcon(), color: _getIconColor()),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(warning.message),
          if (warning.affectedEvents.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Events: ${warning.affectedEvents.map((e) => e.name).join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: const Text('VIEW'),
          ),
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: const Text('DISMISS'),
          ),
      ],
    );
  }

  Color _getBackgroundColor() {
    switch (warning.severity) {
      case WarningSeverity.critical:
        return Colors.red[50]!;
      case WarningSeverity.warning:
        return Colors.orange[50]!;
      case WarningSeverity.info:
        return Colors.blue[50]!;
    }
  }

  IconData _getIcon() {
    switch (warning.type) {
      case WarningType.itemShortage:
        return Icons.error;
      case WarningType.itemRemoved:
        return Icons.delete_forever;
      case WarningType.quantityReduced:
        return Icons.remove_circle;
      case WarningType.eventOverlap:
        return Icons.warning;
    }
  }

  Color _getIconColor() {
    switch (warning.severity) {
      case WarningSeverity.critical:
        return Colors.red;
      case WarningSeverity.warning:
        return Colors.orange;
      case WarningSeverity.info:
        return Colors.blue;
    }
  }

  String _getTitle() {
    switch (warning.type) {
      case WarningType.itemShortage:
        return 'Item Shortage';
      case WarningType.itemRemoved:
        return 'Item Removed';
      case WarningType.quantityReduced:
        return 'Quantity Reduced';
      case WarningType.eventOverlap:
        return 'Event Overlap';
    }
  }
}
