/// Extensions on String
extension StringExtensions on String {
  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize each word
  String get titleCase {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Check if string is a valid email
  bool get isEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  /// Check if string is numeric
  bool get isNumeric => double.tryParse(this) != null;

  /// Truncate with ellipsis
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Convert to nullable (returns null if empty or whitespace only)
  String? get nullIfEmpty {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Extensions on nullable String
extension NullableStringExtensions on String? {
  /// Check if null or empty
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Check if not null and not empty
  bool get isNotNullOrEmpty => !isNullOrEmpty;

  /// Return value or default
  String orDefault(String defaultValue) => isNullOrEmpty ? defaultValue : this!;
}
