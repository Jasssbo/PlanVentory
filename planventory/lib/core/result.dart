/// Result type for handling success/failure without exceptions
/// This pattern makes error handling explicit and type-safe
sealed class Result<T> {
  const Result();

  /// Create a success result
  factory Result.success(T value) = Success<T>;

  /// Create a failure result
  factory Result.failure(AppException error) = Failure<T>;

  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is failure
  bool get isFailure => this is Failure<T>;

  /// Get value or null
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// Get error or null
  AppException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final error) => error,
      };

  /// Transform success value
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Result.success(transform(value)),
        Failure<T>(:final error) => Result.failure(error),
      };

  /// Handle both cases
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException error) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final error) => onFailure(error),
      };
}

/// Success case
final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// Failure case
final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}

/// Base exception class for the app
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' ($code)' : ''}';
}

/// Database-specific exceptions
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(
    super.message, {
    this.fieldErrors,
    super.code,
  });
}

/// Not found exceptions
class NotFoundException extends AppException {
  final String entityType;
  final dynamic entityId;

  NotFoundException(this.entityType, this.entityId)
      : super('$entityType with id $entityId not found', code: 'NOT_FOUND');
}

/// Conflict exceptions (e.g., item shortage)
class ConflictException extends AppException {
  const ConflictException(super.message, {super.code});
}
