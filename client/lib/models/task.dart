import 'package:hive/hive.dart';
import 'enums/task_status.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  String name;

  @HiveField(1)
  int coins;

  @HiveField(2)
  TaskStatus status;

  @HiveField(3)
  String id;

  @HiveField(4)
  DateTime? completedAt;

  @HiveField(5)
  bool isLate; // Track if task was completed late (after 2 AM next day)

  Task({
    required this.name,
    required this.coins,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.isLate = false,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Task copyWith({
    String? name,
    int? coins,
    TaskStatus? status,
    DateTime? completedAt,
    bool? isLate,
    String? id,
  }) {
    return Task(
      name: name ?? this.name,
      coins: coins ?? this.coins,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      isLate: isLate ?? this.isLate,
      id: id ?? this.id,
    );
  }
}