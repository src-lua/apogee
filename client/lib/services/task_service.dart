import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/enums/recurrency_type.dart';
import '../models/enums/task_status.dart';
import 'streak_service.dart';

class TaskService {
  late final Box _dataBox;
  static const String _taskTemplatesKey = 'task_templates';

  TaskService._();
  static final TaskService _instance = TaskService._();
  static TaskService get instance => _instance;

  Future<void> initialize() async {
    _dataBox = Hive.box('apogee_data');
    await StreakService.instance.initialize();
    await _initializeDefaultTemplates();
  }

  Future<void> _initializeDefaultTemplates() async {
    final existingTemplates = getTaskTemplates();

    if (existingTemplates.isEmpty) {
      final defaultTemplates = [
        TaskTemplate(
          id: 'dish_washing',
          name: 'Lavar a louça do dia',
          coins: 15,
          recurrencyType: RecurrencyType.daily,
        ),
        TaskTemplate(
          id: 'competitive_programming',
          name: 'Estudar Programação Competitiva (1h)',
          coins: 40,
          recurrencyType: RecurrencyType.daily,
        ),
        TaskTemplate(
          id: 'house_cleaning',
          name: 'Limpar e organizar a casa (15 min)',
          coins: 20,
          recurrencyType: RecurrencyType.daily,
        ),
        TaskTemplate(
          id: 'piano_practice',
          name: 'Praticar piano (30 min)',
          coins: 30,
          recurrencyType: RecurrencyType.daily,
        ),
      ];

      await saveTaskTemplates(defaultTemplates);
    }
  }

  List<TaskTemplate> getTaskTemplates() {
    try {
      final templateData = _dataBox.get(_taskTemplatesKey);
      if (templateData == null) return [];
      return List<TaskTemplate>.from(templateData);
    } catch (e) {
      if (kDebugMode) print('Error loading task templates: $e');
      return [];
    }
  }

  Future<void> saveTaskTemplates(List<TaskTemplate> templates) async {
    try {
      await _dataBox.put(_taskTemplatesKey, templates);
    } catch (e) {
      if (kDebugMode) print('Error saving task templates: $e');
      rethrow;
    }
  }

  Future<void> addTaskTemplate(TaskTemplate template) async {
    final templates = getTaskTemplates();
    templates.add(template);
    await saveTaskTemplates(templates);

    // Generate tasks for existing days
    await _regenerateAffectedDays(template);
  }

  Future<void> updateTaskTemplate(TaskTemplate updatedTemplate) async {
    final templates = getTaskTemplates();
    final index = templates.indexWhere((t) => t.id == updatedTemplate.id);

    if (index != -1) {
      // Update the template with new modification time
      final updated = updatedTemplate.copyWith(updateModified: true);
      templates[index] = updated;
      await saveTaskTemplates(templates);

      // Notify StreakService of template configuration change
      await StreakService.instance.onTemplateConfigChanged(updated);

      // Regenerate existing days that might be affected
      await _regenerateAffectedDays(updated);
    }
  }

  // Update template without regenerating days - used for toggle operations
  Future<void> updateTaskTemplateWithoutRegeneration(TaskTemplate updatedTemplate) async {
    final templates = getTaskTemplates();
    final index = templates.indexWhere((t) => t.id == updatedTemplate.id);

    if (index != -1) {
      templates[index] = updatedTemplate;
      await saveTaskTemplates(templates);

      // Still notify StreakService even without regeneration
      await StreakService.instance.onTemplateConfigChanged(updatedTemplate);
    }
  }

  Future<void> deleteTaskTemplate(String templateId) async {
    final templates = getTaskTemplates();
    templates.removeWhere((t) => t.id == templateId);
    await saveTaskTemplates(templates);

    // Invalidate cache for deleted template
    StreakService.instance.invalidateCache(templateId);

    // Remove tasks from existing days
    await _removeTasksFromExistingDays(templateId);
  }

  List<Task> getTasksForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final key = normalizedDay.toIso8601String();

    try {
      final taskData = _dataBox.get(key);

      if (taskData == null) {
        final newTasks = _generateTasksForDay(normalizedDay);
        _dataBox.put(key, newTasks);
        return newTasks;
      } else {
        return List<Task>.from(taskData);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading tasks for day $key: $e');
      return _generateTasksForDay(normalizedDay);
    }
  }

  List<Task> _generateTasksForDay(DateTime day) {
    final templates = getTaskTemplates();
    final tasks = <Task>[];

    for (final template in templates) {
      if (template.isActive && template.shouldGenerateForDay(day)) {
        tasks.add(Task(
          name: template.name,
          coins: template.coins,
          id: '${template.id}_${day.toIso8601String()}',
        ));
      }
    }

    return tasks;
  }

  bool _isCompletionLate(DateTime taskDay, DateTime completionTime) {
    // Task is late if completed after 2 AM of the next day
    final nextDay = DateTime(taskDay.year, taskDay.month, taskDay.day + 1);
    final deadline = DateTime(nextDay.year, nextDay.month, nextDay.day, 2, 0, 0);
    return completionTime.isAfter(deadline);
  }

  Future<void> updateTaskStatus(Task task, TaskStatus newStatus, DateTime day) async {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final key = normalizedDay.toIso8601String();

    try {
      List<Task> tasksForDay = getTasksForDay(normalizedDay);
      final taskIndex = tasksForDay.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        final now = DateTime.now();
        final isCompleting = newStatus != TaskStatus.pending && task.status == TaskStatus.pending;
        final isLate = isCompleting ? _isCompletionLate(normalizedDay, now) : task.isLate;

        final updatedTask = task.copyWith(
          status: newStatus,
          completedAt: newStatus != TaskStatus.pending ? now : null,
          isLate: isLate,
        );

        tasksForDay[taskIndex] = updatedTask;
        await _dataBox.put(key, tasksForDay);

        // Update streaks when task status changes
        await _updateStreaksForTaskChange(task.id);
        return;
      }
      throw Exception('Task not found');
    } catch (e) {
      if (kDebugMode) print('Error updating task ${task.id}: $e');
      rethrow;
    }
  }

  Future<void> regenerateTasksForDay(DateTime day) async {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final key = normalizedDay.toIso8601String();

    final newTasks = _generateTasksForDay(normalizedDay);
    await _dataBox.put(key, newTasks);
  }

  Future<void> _regenerateAffectedDays(TaskTemplate template) async {
    try {
      // Get all stored days (keys that look like dates)
      final allKeys = _dataBox.keys
          .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
          .cast<String>()
          .toList();

      for (final key in allKeys) {
        final day = DateTime.parse(key);
        final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);

        // Check if task already exists for this template
        final existingTaskIndex = tasksForDay.indexWhere((task) => task.id.startsWith('${template.id}_'));

        if (existingTaskIndex != -1) {
          // Task exists - update it but preserve status
          final existingTask = tasksForDay[existingTaskIndex];
          final updatedTask = existingTask.copyWith(
            name: template.name,
            coins: template.coins,
          );
          tasksForDay[existingTaskIndex] = updatedTask;
        } else {
          // Task doesn't exist - add new task if template should generate for this day
          if (template.shouldGenerateForDay(day)) {
            final newTask = Task(
              name: template.name,
              coins: template.coins,
              id: '${template.id}_${day.toIso8601String()}',
            );
            tasksForDay.add(newTask);
          }
        }

        // Save updated tasks for this day
        if (tasksForDay.isEmpty) {
          await _dataBox.delete(key);
        } else {
          await _dataBox.put(key, tasksForDay);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error regenerating affected days: $e');
    }
  }

  Future<void> _removeTasksFromExistingDays(String templateId) async {
    try {
      // Get all stored days
      final allKeys = _dataBox.keys
          .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
          .cast<String>()
          .toList();

      for (final key in allKeys) {
        final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);

        // Remove tasks from this template
        final originalLength = tasksForDay.length;
        tasksForDay.removeWhere((task) => task.id.startsWith('${templateId}_'));

        // Save if something was removed
        if (tasksForDay.length != originalLength) {
          if (tasksForDay.isEmpty) {
            await _dataBox.delete(key);
          } else {
            await _dataBox.put(key, tasksForDay);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error removing tasks from existing days: $e');
    }
  }

  Future<void> regenerateAllDays() async {
    try {
      // Get all stored days
      final allKeys = _dataBox.keys
          .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
          .cast<String>()
          .toList();

      for (final key in allKeys) {
        final day = DateTime.parse(key);
        await regenerateTasksForDay(day);
      }
    } catch (e) {
      if (kDebugMode) print('Error regenerating all days: $e');
    }
  }

  Future<void> _updateStreaksForTaskChange(String taskId) async {
    try {
      // Extract template ID from task ID (everything before the last ISO date part)
      final parts = taskId.split('_');
      final templateId = parts.sublist(0, parts.length - 1).join('_');
      final templates = getTaskTemplates();

      // Find template safely
      final templateIndex = templates.indexWhere((t) => t.id == templateId);
      if (templateIndex == -1) {
        if (kDebugMode) print('Template not found for task $taskId (templateId: $templateId)');
        return;
      }

      final template = templates[templateIndex];

      // Use optimized streak update methods
      final affectedTemplates = [template];
      final taskDay = DateTime.parse(taskId.split('_').last);

      // Incremental update - only recalculates this template and day
      await StreakService.instance.updateStreaksForDay(taskDay, affectedTemplates);

      // Update the template with new streak data
      template.streakData = StreakService.instance.calculateTaskStreak(template);
      templates[templateIndex] = template;
      await saveTaskTemplates(templates);
    } catch (e) {
      if (kDebugMode) print('Error updating streaks for task $taskId: $e');
    }
  }

  void dispose() {
    // Box is managed by main app, so we don't close it here
  }
}