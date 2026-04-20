import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../extensions/extensions.dart';
import '../core/core.dart';
import 'event_detail_screen.dart';

/// Calendar view to see events by date
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  List<Event> _eventsForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_focusedMonth.monthYear),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _goToToday,
            tooltip: 'Today',
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildCalendarHeader(context),
              _buildWeekDayLabels(context),
              _buildCalendarGrid(context, provider.events),
              if (_selectedDay != null) ...[
                const Divider(height: 1),
                Expanded(
                  child: _buildEventsForDay(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    return Padding(
      padding: Spacing.horizontalMd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          Text(
            _focusedMonth.monthYear,
            style: context.textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayLabels(BuildContext context) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: Spacing.horizontalMd,
      child: Row(
        children: weekDays
            .map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, List<Event> allEvents) {
    final firstDayOfMonth = _focusedMonth.firstDayOfMonth;
    final lastDayOfMonth = _focusedMonth.lastDayOfMonth;
    final eventProvider = context.read<EventProvider>();

    // Monday = 1, so we subtract 1 to shift
    int startWeekday = firstDayOfMonth.weekday - 1;
    if (startWeekday < 0) startWeekday = 6;

    final daysInMonth = lastDayOfMonth.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Build rows of days
    return Padding(
      padding: Spacing.horizontalMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows, (rowIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (colIndex) {
                final index = rowIndex * 7 + colIndex;
                final dayNumber = index - startWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 44));
                }

                final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final eventsOnDay = allEvents.where((e) {
                  return (e.startDate.isSameDay(date) ||
                      e.endDate.isSameDay(date) ||
                      (e.startDate.isBefore(date) && e.endDate.isAfter(date)));
                }).toList();

                final isSelected = _selectedDay?.isSameDay(date) ?? false;
                final isToday = date.isToday;
                
                // Determine worst status among events on this day
                // Priority: needsRental (red) > hasRental (yellow) > ok
                EventStatus dayStatus = EventStatus.ok;
                for (final e in eventsOnDay) {
                  if (e.id != null) {
                    final status = eventProvider.getEventStatus(e.id!);
                    if (status == EventStatus.needsRental) {
                      dayStatus = EventStatus.needsRental;
                      break; // Red is highest priority
                    } else if (status == EventStatus.hasRental) {
                      dayStatus = EventStatus.hasRental;
                    }
                  }
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _CalendarDayCell(
                      day: dayNumber,
                      isSelected: isSelected,
                      isToday: isToday,
                      eventCount: eventsOnDay.length,
                      status: dayStatus,
                      onTap: () => _selectDay(date, eventsOnDay),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEventsForDay(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Spacing.paddingMd,
          child: Text(
            _selectedDay!.relative,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _eventsForSelectedDay.isEmpty
              ? Center(
                  child: Text(
                    'No events on this day',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _eventsForSelectedDay.length,
                  itemBuilder: (context, index) {
                    final event = _eventsForSelectedDay[index];
                    return EventCard(
                      event: event,
                      status: event.id != null 
                          ? eventProvider.getEventStatus(event.id!) 
                          : EventStatus.ok,
                      onTap: () => _showEventDetails(context, event),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
      _selectedDay = DateTime.now();
      _updateEventsForSelectedDay();
    });
  }

  void _selectDay(DateTime date, List<Event> events) {
    setState(() {
      _selectedDay = date;
      _eventsForSelectedDay = events;
    });
  }

  void _updateEventsForSelectedDay() {
    if (_selectedDay == null) return;
    final provider = context.read<EventProvider>();
    _eventsForSelectedDay = provider.events.where((e) {
      return (e.startDate.isSameDay(_selectedDay!) ||
          e.endDate.isSameDay(_selectedDay!) ||
          (e.startDate.isBefore(_selectedDay!) && e.endDate.isAfter(_selectedDay!)));
    }).toList();
  }

  void _showEventDetails(BuildContext context, Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final int eventCount;
  final EventStatus status;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.eventCount,
    required this.onTap,
    this.status = EventStatus.ok,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    
    // Determine background color based on status
    Color? backgroundColor;
    Color? textColor;
    Color dotColor;
    Color? borderColor;

    if (isSelected) {
      switch (status) {
        case EventStatus.needsRental:
          backgroundColor = colorScheme.error;
          textColor = colorScheme.onError;
          dotColor = colorScheme.onError;
          break;
        case EventStatus.hasRental:
          backgroundColor = Colors.amber.shade700;
          textColor = Colors.white;
          dotColor = Colors.white;
          break;
        case EventStatus.ok:
          backgroundColor = colorScheme.primary;
          textColor = colorScheme.onPrimary;
          dotColor = colorScheme.onPrimary;
          break;
      }
    } else if (eventCount > 0 && status != EventStatus.ok) {
      switch (status) {
        case EventStatus.needsRental:
          backgroundColor = colorScheme.errorContainer;
          textColor = colorScheme.onErrorContainer;
          dotColor = colorScheme.error;
          borderColor = colorScheme.error;
          break;
        case EventStatus.hasRental:
          backgroundColor = Colors.amber.shade50;
          textColor = Colors.amber.shade900;
          dotColor = Colors.amber.shade700;
          borderColor = Colors.amber.shade600;
          break;
        case EventStatus.ok:
          dotColor = colorScheme.primary;
          break;
      }
    } else if (isToday) {
      backgroundColor = colorScheme.primaryContainer;
      textColor = colorScheme.primary;
      dotColor = colorScheme.primary;
    } else {
      dotColor = colorScheme.primary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.borderMd,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: Radii.borderMd,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : isToday && !isSelected
                  ? Border.all(color: colorScheme.primary)
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected || isToday || status != EventStatus.ok 
                    ? FontWeight.bold 
                    : null,
                color: textColor,
              ),
            ),
            if (eventCount > 0)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
