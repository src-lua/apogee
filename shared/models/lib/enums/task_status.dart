import 'package:json_annotation/json_annotation.dart';

/// Represents the different states a task can be in
/// Used consistently across client and server
@JsonEnum()
enum TaskStatus {
  @JsonValue('pending')
  pending,

  @JsonValue('completed')
  completed,

  @JsonValue('not_necessary')
  notNecessary,

  @JsonValue('not_did')
  notDid;

  /// Human-readable description of the task status
  String get description {
    switch (this) {
      case TaskStatus.pending:
        return 'Pendente';
      case TaskStatus.completed:
        return 'Concluída';
      case TaskStatus.notNecessary:
        return 'Não necessária';
      case TaskStatus.notDid:
        return 'Não fez';
    }
  }

  /// Whether this status represents a completed/logged state
  /// Used for XP and streak calculations
  bool get isLogged {
    return this != TaskStatus.pending;
  }

  /// Whether this status should award full XP (20 points)
  bool get isFullCompletion {
    return this == TaskStatus.completed;
  }

  /// Whether this status should award partial XP (10 points)
  bool get isPartialCompletion {
    return this == TaskStatus.notNecessary || this == TaskStatus.notDid;
  }
}