import 'package:flutter/foundation.dart';
import 'app_config.dart';

/// Simple logger that respects environment settings
class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) {
    if (AppConfig.enableLogging) {
      _log('DEBUG', message, tag: tag);
    }
  }

  static void info(String message, {String? tag}) {
    if (AppConfig.enableLogging) {
      _log('INFO', message, tag: tag);
    }
  }

  static void warning(String message, {String? tag}) {
    _log('WARNING', message, tag: tag);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag);
    if (error != null && AppConfig.enableLogging) {
      debugPrint('  Error: $error');
    }
    if (stackTrace != null && AppConfig.enableLogging) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  static void _log(String level, String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('[$timestamp] [$level] $tagStr$message');
  }
}
