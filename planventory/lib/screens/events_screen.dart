import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import 'event_detail_screen.dart';

/// List of all events
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.events.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => context.read<AppStateProvider>().refreshAll(),
            child: _buildEventsList(context, provider),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    final provider = context.read<EventProvider>();
    showSearch(
      context: context,
      delegate: _EventSearchDelegate(
        events: provider.events,
        eventProvider: provider,
        onSelected: (event) => _showEventDetails(context, event),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first event to get started',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddEventDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, EventProvider provider) {
    final upcomingEvents = provider.upcomingEvents;
    final pastEvents = provider.pastEvents;

    if (upcomingEvents.isEmpty && pastEvents.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      slivers: [
        if (upcomingEvents.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: Spacing.paddingMd,
              child: Text(
                'Upcoming Events',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final event = upcomingEvents[index];
                return EventCard(
                  event: event,
                  status: event.id != null 
                      ? provider.getEventStatus(event.id!) 
                      : EventStatus.ok,
                  onTap: () => _showEventDetails(context, event),
                  onDelete: () => _confirmDeleteEvent(context, event),
                );
              },
              childCount: upcomingEvents.length,
            ),
          ),
        ],
        if (pastEvents.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: Spacing.paddingMd,
              child: Text(
                'Past Events',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Opacity(
                opacity: 0.6,
                child: EventCard(
                  event: pastEvents[index],
                  onTap: () => _showEventDetails(context, pastEvents[index]),
                  onDelete: () => _confirmDeleteEvent(context, pastEvents[index]),
                ),
              ),
              childCount: pastEvents.length,
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Future<void> _confirmDeleteEvent(BuildContext context, Event event) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Are you sure you want to delete "${event.name}"?\n\nThis will also remove all item allocations for this event.'),
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
      await provider.deleteEvent(event.id!);
      if (mounted) {
        this.context.read<AppStateProvider>().notifyRefreshNeeded();
        this.context.showSuccess('Event deleted');
      }
    }
  }

  void _showEventDetails(BuildContext context, Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddEventDialog(),
    );
  }
}

/// Dialog to add a new event
class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Event'),
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
                    labelText: 'Event Name *',
                    hintText: 'e.g., Wedding Reception',
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
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Grand Hotel',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date'),
                  subtitle: Text(_startDate.formattedWithTime),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End Date'),
                  subtitle: Text(_endDate.formattedWithTime),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: false),
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
          onPressed: _isSaving ? null : _saveEvent,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart ? DateTime.now() : _startDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null && mounted) {
        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isStart) {
            _startDate = newDateTime;
            // Ensure end date is after start date
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(hours: 4));
            }
          } else {
            _endDate = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final event = Event(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().nullIfEmpty,
      location: _locationController.text.trim().nullIfEmpty,
      startDate: _startDate,
      endDate: _endDate,
    );

    final provider = context.read<EventProvider>();
    final id = await provider.addEvent(event);

    if (mounted) {
      Navigator.pop(context);
      if (id > 0) {
        context.read<AppStateProvider>().notifyRefreshNeeded();
        context.showSuccess('Event created successfully');
      } else {
        context.showError('Failed to create event');
      }
    }
  }
}

/// Search delegate for events
class _EventSearchDelegate extends SearchDelegate<Event?> {
  final List<Event> events;
  final EventProvider eventProvider;
  final Function(Event) onSelected;

  _EventSearchDelegate({
    required this.events,
    required this.eventProvider,
    required this.onSelected,
  });

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
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    final filtered = events.where((event) {
      final queryLower = query.toLowerCase();
      return event.name.toLowerCase().contains(queryLower) ||
          (event.description?.toLowerCase().contains(queryLower) ?? false) ||
          (event.location?.toLowerCase().contains(queryLower) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final event = filtered[index];
        return EventCard(
          event: event,
          status: event.id != null
              ? eventProvider.getEventStatus(event.id!)
              : EventStatus.ok,
          onTap: () {
            close(context, event);
            onSelected(event);
          },
        );
      },
    );
  }
}
