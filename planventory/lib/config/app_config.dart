import 'package:flutter/foundation.dart';

/// Environment types for the app
enum Environment { development, staging, production }

/// Central configuration class for the app
class AppConfig {
  static Environment _environment = Environment.development;
  static bool _isInitialized = false;

  AppConfig._();

  /// Initialize app configuration
  static void init({Environment environment = Environment.development}) {
    if (_isInitialized) return;
    _environment = environment;
    _isInitialized = true;
  }

  /// Current environment
  static Environment get environment => _environment;

  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;

  /// App name
  static const String appName = 'PlanVentory';

  /// App version (should be synced with pubspec.yaml)
  static const String appVersion = '1.0.0';

  /// Database name
  static const String databaseName = 'planventory.db';

  /// Database version (increment when schema changes)
  static const int databaseVersion = 1;

  /// Enable logging based on environment
  static bool get enableLogging =>
      _environment == Environment.development || isDebug;

  /// API base URL (for future cloud sync)
  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://localhost:8080/api';
      case Environment.staging:
        return 'https://staging.planventory.app/api';
      case Environment.production:
        return 'https://api.planventory.app/api';
    }
  }
}
