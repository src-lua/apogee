import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/task_streak_data.dart';
import '../models/enums/task_status.dart';

class StreakService {
  late final Box _dataBox;
  static const String _globalStreakKey = 'global_streak_data';

  StreakService._();
  static final StreakService _instance = StreakService._();
  static StreakService get instance => _instance;

  Future<void> initialize() async {
    _dataBox = Hive.box('apogee_data');
  }

  TaskStreakData getGlobalStreakData() {
    try {
      final data = _dataBox.get(_globalStreakKey);
      if (data == null) {
        final newData = TaskStreakData();
        _dataBox.put(_globalStreakKey, newData);
        return newData;
      }
      return data as TaskStreakData;
    } catch (e) {
      if (kDebugMode) print('Error loading global streak data: $e');
      return TaskStreakData();
    }
  }

  Future<void> saveGlobalStreakData(TaskStreakData data) async {
    try {
      await _dataBox.put(_globalStreakKey, data);
    } catch (e) {
      if (kDebugMode) print('Error saving global streak data: $e');
    }
  }

  TaskStreakData calculateTaskStreak(TaskTemplate template) {
    final allKeys = _dataBox.keys
        .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
        .cast<String>()
        .toList()
      ..sort();

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    int totalCompletions = 0;
    DateTime? lastCompletedDate;
    DateTime? lastExpectedDate;

    for (final key in allKeys) {
      final day = DateTime.parse(key);
      final dayOnly = DateTime(day.year, day.month, day.day);

      if (!template.shouldGenerateForDay(dayOnly)) continue;

      final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);
      final task = tasksForDay.firstWhere(
        (t) => t.id.startsWith('${template.id}_'),
        orElse: () => Task(name: '', coins: 0),
      );

      final isCompleted = task.name.isNotEmpty &&
          (task.status == TaskStatus.completed || task.status == TaskStatus.notNecessary || task.status == TaskStatus.notDid);

      if (isCompleted) {
        tempStreak++;
        totalCompletions++;
        lastCompletedDate = dayOnly;
        bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;
      } else {
        tempStreak = 0;
      }

      lastExpectedDate = dayOnly;
    }

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Calcular streak atual: usar os dias ordenados e ir de trás para frente
    currentStreak = 0;

    // Filtrar apenas dias onde a tarefa deveria existir e reverter a ordem
    final relevantDays = allKeys
        .map((key) => DateTime.parse(key))
        .map((day) => DateTime(day.year, day.month, day.day))
        .where((day) => template.shouldGenerateForDay(day))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Ordem decrescente (mais recente primeiro)

    // Contar streak a partir do dia mais recente
    for (final day in relevantDays) {
      final key = DateTime.utc(day.year, day.month, day.day).toIso8601String();
      final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);
      final task = tasksForDay.firstWhere(
        (t) => t.id.startsWith('${template.id}_'),
        orElse: () => Task(name: '', coins: 0),
      );

      final isCompleted = task.name.isNotEmpty &&
          (task.status == TaskStatus.completed || task.status == TaskStatus.notNecessary || task.status == TaskStatus.notDid);

      if (isCompleted) {
        currentStreak++;
      } else {
        // Primeira tarefa não completada = fim da streak atual
        break;
      }
    }

    return TaskStreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: lastCompletedDate,
      totalCompletions: totalCompletions,
    );
  }

  Future<void> updateTaskStreak(TaskTemplate template) async {
    final streakData = calculateTaskStreak(template);
    template.streakData = streakData;
  }

  TaskStreakData calculateGlobalLoggingStreak() {
    final allKeys = _dataBox.keys
        .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
        .cast<String>()
        .toList()
      ..sort();

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    int totalLoggedDays = 0;
    DateTime? lastLoggedDate;

    for (final key in allKeys) {
      final day = DateTime.parse(key);
      final dayOnly = DateTime(day.year, day.month, day.day);
      final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);

      final hasAnyLogging = tasksForDay.any((task) =>
          task.status == TaskStatus.completed || task.status == TaskStatus.notNecessary || task.status == TaskStatus.notDid);

      if (hasAnyLogging) {
        tempStreak++;
        totalLoggedDays++;
        lastLoggedDate = dayOnly;
        bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;
      } else {
        tempStreak = 0;
      }
    }

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (lastLoggedDate != null) {
      final daysSinceLastLogged = today.difference(lastLoggedDate).inDays;
      currentStreak = daysSinceLastLogged <= 1 ? tempStreak : 0;
    }

    return TaskStreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: lastLoggedDate,
      totalCompletions: totalLoggedDays,
      lastCalculated: DateTime.now(),
    );
  }

  Future<void> updateGlobalLoggingStreak() async {
    final streakData = calculateGlobalLoggingStreak();
    await saveGlobalStreakData(streakData);
  }

  Future<void> recalculateAllStreaks(List<TaskTemplate> templates) async {
    for (final template in templates) {
      await updateTaskStreak(template);
    }
    await updateGlobalLoggingStreak();
  }

  void dispose() {
    // Box is managed by main app
  }
}