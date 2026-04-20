import 'package:flutter/material.dart';
import '../models/models.dart';

/// Card widget to display an event summary with status indicators
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EventStatus status;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onDelete,
    this.status = EventStatus.ok,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Determine card color based on status
    Color? cardColor;
    Color? textColor;
    
    switch (status) {
      case EventStatus.needsRental:
        cardColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        break;
      case EventStatus.hasRental:
        cardColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        break;
      case EventStatus.ok:
        cardColor = null;
        textColor = null;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildStatusIcon(colorScheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                        ),
                        _buildStatusBadge(colorScheme),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: textColor?.withAlpha(180) ?? colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                          style: TextStyle(
                            color: textColor?.withAlpha(180) ?? colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: textColor?.withAlpha(180) ?? colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                color: textColor?.withAlpha(180) ?? colorScheme.outline,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  onPressed: onDelete,
                  tooltip: 'Delete event',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ColorScheme colorScheme) {
    switch (status) {
      case EventStatus.needsRental:
        return Tooltip(
          message: 'Material shortage - needs rental',
          child: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 20,
          ),
        );
      case EventStatus.hasRental:
        return Tooltip(
          message: 'Rental in progress',
          child: Icon(
            Icons.local_shipping_outlined,
            color: Colors.amber.shade800,
            size: 20,
          ),
        );
      case EventStatus.ok:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    IconData icon;
    Color backgroundColor;
    Color iconColor;

    switch (status) {
      case EventStatus.needsRental:
        icon = Icons.warning_amber_rounded;
        backgroundColor = colorScheme.error.withAlpha(50);
        iconColor = colorScheme.error;
        break;
      case EventStatus.hasRental:
        icon = Icons.local_shipping;
        backgroundColor = Colors.amber.shade100;
        iconColor = Colors.amber.shade800;
        break;
      case EventStatus.ok:
        if (event.isOngoing) {
          icon = Icons.play_circle_filled;
          backgroundColor = Colors.green.shade100;
          iconColor = Colors.green.shade700;
        } else if (event.isPast) {
          icon = Icons.check_circle;
          backgroundColor = Colors.grey.shade200;
          iconColor = Colors.grey.shade600;
        } else {
          icon = Icons.schedule;
          backgroundColor = Colors.blue.shade100;
          iconColor = Colors.blue.shade700;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
