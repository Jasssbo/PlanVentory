import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import '../widgets/widgets.dart';
import 'event_detail_screen.dart';
import 'inventory_screen.dart';

/// Main home screen with dashboard overview
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanVentory'),
          actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.showSnackBar('Settings coming soon');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Use global refresh to update all screens
          await context.read<AppStateProvider>().refreshAll();
        },
        child: SingleChildScrollView(
          padding: Spacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(context),
              const SizedBox(height: 24),
              _buildQuickStats(context),
              const SizedBox(height: 24),
              _buildUpcomingEvents(context),
              const SizedBox(height: 24),
              _buildRecentItems(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to PlanVentory',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your events and inventory all in one place.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.inventory_2,
              size: 64,
              color: context.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Consumer2<EventProvider, InventoryProvider>(
      builder: (context, eventProvider, inventoryProvider, _) {
        final conflictCount = eventProvider.eventsWithConflicts.length;
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.event,
                    label: 'Upcoming Events',
                    value: '${eventProvider.upcomingEvents.length}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.inventory_2,
                    label: 'Total Items',
                    value: '${inventoryProvider.items.length}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.category,
                    label: 'Categories',
                    value: '${inventoryProvider.categories.length}',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            if (conflictCount > 0) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: Spacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$conflictCount event${conflictCount > 1 ? 's' : ''} with material shortages',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, provider, _) {
        final upcoming = provider.upcomingEvents.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Events',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<AppStateProvider>().navigateToTab(2); // Events tab
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              Card(
                child: Padding(
                  padding: Spacing.paddingLg,
                  child: Center(
                    child: Text(
                      'No upcoming events',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...upcoming.map((event) => EventCard(
                    event: event,
                    status: event.id != null 
                        ? provider.getEventStatus(event.id!) 
                        : EventStatus.ok,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                  )),
          ],
        );
      },
    );
  }

  Widget _buildRecentItems(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final recentItems = provider.items.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inventory Items',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<AppStateProvider>().navigateToTab(3); // Inventory tab
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: recentItems.isEmpty
                  ? Padding(
                      padding: Spacing.paddingLg,
                      child: Center(
                        child: Text(
                          'No items in inventory',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: recentItems
                          .map((item) => ItemTile(
                                item: item,
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AddItemDialog(item: item),
                                  );
                                },
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
