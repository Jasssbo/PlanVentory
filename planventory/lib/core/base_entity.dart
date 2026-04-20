/// Base class for entities with an ID
abstract class BaseEntity {
  int? get id;
  DateTime get createdAt;
  DateTime get updatedAt;

  bool get isNew => id == null;
  bool get isPersisted => id != null;
}

/// Mixin for entities that can be soft-deleted
mixin SoftDeletable {
  DateTime? get deletedAt;
  bool get isDeleted => deletedAt != null;
}
