/// App-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'PlanVentory';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'planventory.db';
  static const int databaseVersion = 1;

  // Event statuses
  static const String statusUpcoming = 'upcoming';
  static const String statusOngoing = 'ongoing';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // Default categories
  static const List<String> defaultCategories = [
    'Audio',
    'Lighting',
    'Furniture',
    'Decoration',
    'Catering',
    'Electronics',
    'Textiles',
    'Other',
  ];
}
