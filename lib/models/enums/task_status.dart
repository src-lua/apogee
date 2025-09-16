import 'package:hive/hive.dart';

part 'task_status.g.dart';

@HiveType(typeId: 3)
enum TaskStatus {
  @HiveField(0)
  pending,     // Task not completed yet

  @HiveField(1)
  completed,   // Task completed - user gets coins

  @HiveField(2)
  notNecessary, // Task not necessary today - no penalty, no reward

  @HiveField(3)
  notDid,      // Task not done - no coins, but can still earn XP later
}

extension TaskStatusExtension on TaskStatus {
  String get displayName {
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

  String get description {
    switch (this) {
      case TaskStatus.pending:
        return 'Aguardando conclusão';
      case TaskStatus.completed:
        return 'Parabéns! Você ganhou as moedas';
      case TaskStatus.notNecessary:
        return 'Tarefa não era necessária hoje';
      case TaskStatus.notDid:
        return 'Não completou, mas pode ganhar XP mais tarde';
    }
  }
}