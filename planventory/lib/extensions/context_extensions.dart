import 'package:flutter/material.dart';

/// Extensions on BuildContext for easier access to common properties
extension BuildContextExtensions on BuildContext {
  /// Get current theme
  ThemeData get theme => Theme.of(this);

  /// Get current color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get current text theme
  TextTheme get textTheme => theme.textTheme;

  /// Get screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.paddingOf(this);

  /// Check if dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Check if light mode
  bool get isLightMode => theme.brightness == Brightness.light;

  /// Check if compact screen (mobile)
  bool get isCompact => screenWidth < 600;

  /// Check if medium screen (tablet)
  bool get isMedium => screenWidth >= 600 && screenWidth < 1200;

  /// Check if expanded screen (desktop)
  bool get isExpanded => screenWidth >= 1200;

  /// Show a snackbar with message
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }

  /// Show a success snackbar
  void showSuccess(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Show an error snackbar
  void showError(String message) => showSnackBar(message, isError: true);
}
