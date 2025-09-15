import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  String name;

  @HiveField(1)
  int points;

  @HiveField(2)
  bool finished;

  Task({
    required this.name,
    required this.points,
    this.finished = false,
  });
}