import 'package:hive/hive.dart';

part 'recurrency_type.g.dart';

@HiveType(typeId: 1)
enum RecurrencyType {
  @HiveField(0)
  daily,

  @HiveField(1)
  weekly,

  @HiveField(2)
  monthly,

  @HiveField(3)
  custom,

  @HiveField(4)
  none,
}

extension RecurrencyTypeExtension on RecurrencyType {
  String get displayName {
    switch (this) {
      case RecurrencyType.daily:
        return 'Diário';
      case RecurrencyType.weekly:
        return 'Semanal';
      case RecurrencyType.monthly:
        return 'Mensal';
      case RecurrencyType.custom:
        return 'Personalizado';
      case RecurrencyType.none:
        return 'Sem recorrência';
    }
  }
}