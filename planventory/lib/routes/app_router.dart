import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../screens/screens.dart';
import '../models/models.dart';

/// Central router for the app
class AppRouter {
  AppRouter._();

  /// Generate route based on settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final pathSegments = uri.pathSegments;

    // Home
    if (settings.name == AppRoutes.home) {
      return _buildRoute(const HomeScreen(), settings);
    }

    // Calendar
    if (settings.name == AppRoutes.calendar) {
      return _buildRoute(const CalendarScreen(), settings);
    }

    // Inventory
    if (settings.name == AppRoutes.inventory) {
      return _buildRoute(const InventoryScreen(), settings);
    }

    // Event detail: expects Event object as argument
    if (pathSegments.length == 2 && pathSegments[0] == 'event') {
      final event = settings.arguments as Event?;
      if (event != null) {
        return _buildRoute(EventDetailScreen(event: event), settings);
      }
    }

    // Default: 404
    return _buildRoute(const _NotFoundScreen(), settings);
  }

  /// Build a standard route with animation
  static Route<dynamic> _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }

  /// Navigate to a named route
  static Future<T?> navigateTo<T>(BuildContext context, String routeName,
      {Object? arguments}) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  /// Navigate and replace current route
  static Future<T?> navigateReplace<T>(BuildContext context, String routeName,
      {Object? arguments}) {
    return Navigator.pushReplacementNamed<T, dynamic>(
      context,
      routeName,
      arguments: arguments,
    );
  }

  /// Pop back to previous screen
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  /// Pop until reaching a specific route
  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }
}

/// 404 Not Found screen
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Page not found', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
