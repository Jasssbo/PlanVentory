/// Extensions on List
extension ListExtensions<T> on List<T> {
  /// Get first element or null if empty
  T? get firstOrNull => isEmpty ? null : first;

  /// Get last element or null if empty
  T? get lastOrNull => isEmpty ? null : last;

  /// Find first element matching predicate or null
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// Safe index access
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// Split list into chunks of given size
  List<List<T>> chunked(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }
}

/// Extensions on Iterable
extension IterableExtensions<T> on Iterable<T> {
  /// Sum of elements (requires numeric type)
  num sumBy(num Function(T) selector) {
    num sum = 0;
    for (final element in this) {
      sum += selector(element);
    }
    return sum;
  }

  /// Group elements by key
  Map<K, List<T>> groupBy<K>(K Function(T) keySelector) {
    final map = <K, List<T>>{};
    for (final element in this) {
      final key = keySelector(element);
      (map[key] ??= []).add(element);
    }
    return map;
  }

  /// Distinct elements by key
  Iterable<T> distinctBy<K>(K Function(T) keySelector) {
    final seen = <K>{};
    return where((element) => seen.add(keySelector(element)));
  }
}
