/// Named route paths used throughout the app
class AppRoutes {
  AppRoutes._();

  // Main navigation
  static const String home = '/';
  static const String calendar = '/calendar';
  static const String inventory = '/inventory';
  static const String settings = '/settings';

  // Events
  static const String eventDetail = '/event/:id';
  static const String eventCreate = '/event/create';
  static const String eventEdit = '/event/:id/edit';

  // Items
  static const String itemDetail = '/item/:id';
  static const String itemCreate = '/item/create';
  static const String itemEdit = '/item/:id/edit';

  // Allocation
  static const String allocateItems = '/event/:id/allocate';

  /// Helper to create event detail route
  static String eventDetailPath(int id) => '/event/$id';

  /// Helper to create event edit route
  static String eventEditPath(int id) => '/event/$id/edit';

  /// Helper to create item detail route
  static String itemDetailPath(int id) => '/item/$id';

  /// Helper to create item edit route
  static String itemEditPath(int id) => '/item/$id/edit';

  /// Helper to create allocation route
  static String allocateItemsPath(int eventId) => '/event/$eventId/allocate';
}
