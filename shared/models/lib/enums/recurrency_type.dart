import 'package:json_annotation/json_annotation.dart';

/// Defines how frequently a task template should generate tasks
/// Supports various recurrence patterns for flexible scheduling
@JsonEnum()
enum RecurrencyType {
  @JsonValue('none')
  none,

  @JsonValue('daily')
  daily,

  @JsonValue('weekly')
  weekly,

  @JsonValue('monthly')
  monthly,

  @JsonValue('custom')
  custom;

  /// Human-readable description of the recurrency type
  String get description {
    switch (this) {
      case RecurrencyType.none:
        return 'Sem recorrência';
      case RecurrencyType.daily:
        return 'Diário';
      case RecurrencyType.weekly:
        return 'Semanal';
      case RecurrencyType.monthly:
        return 'Mensal';
      case RecurrencyType.custom:
        return 'Personalizado';
    }
  }

  /// Whether this recurrency type requires custom day configuration
  bool get requiresCustomDays {
    return this == RecurrencyType.weekly ||
           this == RecurrencyType.monthly ||
           this == RecurrencyType.custom;
  }
}