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

  /// Enable logging based on environment
  static bool get enableLogging =>
      _environment == Environment.development || isDebug;
}
