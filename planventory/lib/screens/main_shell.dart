import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../extensions/extensions.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'inventory_screen.dart';
import 'events_screen.dart';
import 'rentals_screen.dart';
import 'settings_screen.dart';

/// Main shell with bottom navigation bar
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _isLoading = true;

  final List<Widget> _screens = const [
    HomeScreen(),
    CalendarScreen(),
    EventsScreen(),
    InventoryScreen(),
    RentalsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Defer loading to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    // Load initial data
    final inventoryProvider = context.read<InventoryProvider>();
    final eventProvider = context.read<EventProvider>();

    await Future.wait([
      inventoryProvider.loadItems(),
      eventProvider.loadEvents(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _setCurrentIndex(int index) {
    context.read<AppStateProvider>().navigateToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading PlanVentory...',
                style: context.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final currentIndex = appState.selectedTabIndex;

        // Adaptive layout: Rail for desktop, Bottom nav for mobile
        if (context.isExpanded) {
          return _buildDesktopLayout(currentIndex);
        }

        return _buildMobileLayout(currentIndex);
      },
    );
  }

  Widget _buildMobileLayout(int currentIndex) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _setCurrentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Rentals',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(int currentIndex) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: _setCurrentIndex,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.inventory,
                size: 32,
                color: context.colorScheme.primary,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: Text('Events'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Inventory'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Rentals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[currentIndex],
          ),
        ],
      ),
    );
  }
}
