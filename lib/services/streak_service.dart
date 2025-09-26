import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/task_streak_data.dart';
import '../models/enums/task_status.dart';

class StreakService {
  late final Box _dataBox;
  static const String _globalStreakKey = 'global_streak_data';

  // Cache system - O(1) lookups
  final Map<String, TaskStreakData> _streakCache = {};
  final Map<String, int> _templateVersions = {};

  // Pre-computed indexes - eliminates O(n) regex operations
  List<DateTime>? _dayIndex;
  Map<String, Map<String, Task>>? _tasksByDayAndTemplate;
  bool _indexesDirty = true;

  StreakService._();
  static final StreakService _instance = StreakService._();
  static StreakService get instance => _instance;

  Future<void> initialize() async {
    _dataBox = Hive.box('apogee_data');
    _rebuildIndexes();
  }

  /// Rebuild indexes once - O(n) instead of O(n²)
  void _rebuildIndexes() {
    if (!_indexesDirty) return;

    final dayKeys = _dataBox.keys
        .whereType<String>()
        .where((key) => RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
        .toList();

    // Pre-sort all days once
    _dayIndex = dayKeys
        .map((key) => DateTime.parse(key))
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort();

    // Build task lookup table - O(n) instead of O(n²)
    _tasksByDayAndTemplate = {};
    for (final key in dayKeys) {
      final day = DateTime.parse(key);
      final dayOnly = DateTime(day.year, day.month, day.day);
      final dayKey = dayOnly.toIso8601String().split('T')[0];

      final tasksForDay = List<Task>.from(_dataBox.get(key) ?? []);
      _tasksByDayAndTemplate![dayKey] = {};

      if (kDebugMode) {
        print('Processing day $dayKey from storage key $key: ${tasksForDay.length} tasks');
      }

      for (final task in tasksForDay) {
        // Extract template ID from task ID (format: templateId_YYYY-MM-DDTHH:mm:ss.sssZ)
        // Find the last occurrence of an ISO date pattern
        final parts = task.id.split('_');
        // Template ID is everything except the last part (which is the ISO date)
        final templateId = parts.sublist(0, parts.length - 1).join('_');
        _tasksByDayAndTemplate![dayKey]![templateId] = task;

        if (kDebugMode) {
          print('  Found task: ${task.name} (id=${task.id}, templateId=$templateId, status=${task.status})');
        }
      }
    }

    _indexesDirty = false;
    if (kDebugMode) print('Rebuilt indexes: ${_dayIndex?.length} days, ${_tasksByDayAndTemplate?.length} day entries');
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
    // Check cache first - O(1) lookup
    final cacheKey = '${template.id}_${template.lastModified.millisecondsSinceEpoch}';
    if (_streakCache.containsKey(cacheKey)) {
      return _streakCache[cacheKey]!;
    }

    _rebuildIndexes(); // Ensure indexes are current

    if (_dayIndex == null || _tasksByDayAndTemplate == null) {
      return TaskStreakData();
    }

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    int totalCompletions = 0;
    DateTime? lastCompletedDate;

    // Historical logic: Check if template was EVER active for this day
    bool wasTemplateActiveForDay(DateTime day, TaskTemplate template) {
      // Strategy: If a task exists for this day/template, the template was active
      // This preserves historical streaks even when template config changes
      final dayKey = day.toIso8601String().split('T')[0];
      final task = _tasksByDayAndTemplate![dayKey]?[template.id];

      // If task exists, template was definitely active that day
      if (task != null && task.name.isNotEmpty) {
        if (kDebugMode) print('  Day $dayKey: task exists for ${template.name}');
        return true;
      }

      // If no task exists, check current template rules
      // (for days where tasks weren't generated yet or template was truly inactive)
      final shouldGenerate = template.shouldGenerateForDay(day);
      if (kDebugMode) print('  Day $dayKey: no task for ${template.name}, shouldGenerate=$shouldGenerate');
      return shouldGenerate;
    }

    // Forward pass for best streak and total completions - O(n)
    for (final day in _dayIndex!) {
      if (!wasTemplateActiveForDay(day, template)) continue;

      final dayKey = day.toIso8601String().split('T')[0];
      final task = _tasksByDayAndTemplate![dayKey]?[template.id];

      final isCompleted = task != null &&
          task.name.isNotEmpty &&
          (task.status == TaskStatus.completed ||
           task.status == TaskStatus.notNecessary ||
           task.status == TaskStatus.notDid);

      if (kDebugMode) {
        print('  Forward pass day $dayKey: task=${task?.name ?? 'null'}, status=${task?.status}, isCompleted=$isCompleted');
      }

      if (isCompleted) {
        tempStreak++;
        totalCompletions++;
        lastCompletedDate = day;
        bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;
      } else {
        tempStreak = 0;
      }
    }

    // Reverse pass for current streak - O(n) worst case, but often breaks early
    // Start from today and go backwards, only count days up to today
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final reverseDays = _dayIndex!.reversed.where(
        (day) => wasTemplateActiveForDay(day, template) && !day.isAfter(today)
    ).toList();

    if (kDebugMode) {
      print('  Starting reverse pass for current streak calculation. Found ${reverseDays.length} relevant days');
    }

    for (final day in reverseDays) {
      final dayKey = day.toIso8601String().split('T')[0];
      final task = _tasksByDayAndTemplate![dayKey]?[template.id];

      final isCompleted = task != null &&
          task.name.isNotEmpty &&
          (task.status == TaskStatus.completed ||
           task.status == TaskStatus.notNecessary ||
           task.status == TaskStatus.notDid);

      if (kDebugMode) {
        print('  Reverse pass day $dayKey: task=${task?.name ?? 'null'}, status=${task?.status}, isCompleted=$isCompleted, currentStreak=$currentStreak');
      }

      if (isCompleted) {
        currentStreak++;
      } else {
        if (kDebugMode) print('  Breaking current streak at day $dayKey (currentStreak was $currentStreak)');
        break; // First incomplete task breaks the streak
      }
    }

    final result = TaskStreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: lastCompletedDate,
      totalCompletions: totalCompletions,
      lastCalculated: DateTime.now(),
    );

    // Cache the result
    _streakCache[cacheKey] = result;
    _cleanupCache(); // Prevent memory leaks

    if (kDebugMode) {
      print('Calculated streak for ${template.name}: current=${result.currentStreak}, best=${result.bestStreak}, total=${result.totalCompletions}');
    }

    return result;
  }

  Future<void> updateTaskStreak(TaskTemplate template) async {
    final streakData = calculateTaskStreak(template);
    template.streakData = streakData;
  }

  TaskStreakData calculateGlobalLoggingStreak() {
    // Check cache first
    const cacheKey = 'global_logging_streak';
    if (_streakCache.containsKey(cacheKey)) {
      final cached = _streakCache[cacheKey]!;
      // Cache is valid for 1 hour to balance performance vs freshness
      if (cached.lastCalculated != null &&
          DateTime.now().difference(cached.lastCalculated!).inHours < 1) {
        return cached;
      }
    }

    _rebuildIndexes();

    if (_dayIndex == null || _tasksByDayAndTemplate == null) {
      return TaskStreakData();
    }

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    int totalLoggedDays = 0;
    DateTime? lastLoggedDate;

    // Forward pass using pre-computed indexes - O(n)
    for (final day in _dayIndex!) {
      final dayKey = day.toIso8601String().split('T')[0];
      final tasksForDay = _tasksByDayAndTemplate![dayKey]?.values ?? [];

      final hasAnyLogging = tasksForDay.any((task) =>
          task.status == TaskStatus.completed ||
          task.status == TaskStatus.notNecessary ||
          task.status == TaskStatus.notDid);

      if (hasAnyLogging) {
        tempStreak++;
        totalLoggedDays++;
        lastLoggedDate = day;
        bestStreak = tempStreak > bestStreak ? tempStreak : bestStreak;
      } else {
        tempStreak = 0;
      }
    }

    // Calculate current streak with reverse pass - same logic as individual streaks
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final reverseDays = _dayIndex!.reversed.where((day) => !day.isAfter(today)).toList();

    currentStreak = 0;
    for (final day in reverseDays) {
      final dayKey = day.toIso8601String().split('T')[0];
      final tasksForDay = _tasksByDayAndTemplate![dayKey]?.values ?? [];

      final hasAnyLogging = tasksForDay.any((task) =>
          task.status == TaskStatus.completed ||
          task.status == TaskStatus.notNecessary ||
          task.status == TaskStatus.notDid);

      if (hasAnyLogging) {
        currentStreak++;
        if (kDebugMode) {
          print('Global reverse pass day $dayKey: hasLogging=true, currentStreak=$currentStreak');
        }
      } else {
        if (kDebugMode) {
          print('Global reverse pass day $dayKey: hasLogging=false, breaking streak (was $currentStreak)');
        }
        break; // First day without logging breaks the streak
      }
    }

    if (kDebugMode) {
      print('Global streak calc: currentStreak=$currentStreak, bestStreak=$bestStreak, totalLoggedDays=$totalLoggedDays');
    }

    final result = TaskStreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: lastLoggedDate,
      totalCompletions: totalLoggedDays,
      lastCalculated: DateTime.now(),
    );

    // Cache the result
    _streakCache[cacheKey] = result;
    _cleanupCache(); // Prevent memory leaks
    return result;
  }

  Future<void> updateGlobalLoggingStreak() async {
    final streakData = calculateGlobalLoggingStreak();
    await saveGlobalStreakData(streakData);
  }

  /// Invalidate cache for specific template or all caches
  void invalidateCache([String? templateId]) {
    if (templateId != null) {
      // Remove all cache entries for this template
      _streakCache.removeWhere((key, _) => key.startsWith('${templateId}_'));
    } else {
      // Clear all caches
      _streakCache.clear();
    }
    _indexesDirty = true;
  }

  /// Incremental update when tasks change for a specific day
  Future<void> updateStreaksForDay(DateTime day, List<TaskTemplate> affectedTemplates) async {
    _indexesDirty = true; // Mark indexes for rebuild

    // Only invalidate caches for affected templates
    for (final template in affectedTemplates) {
      invalidateCache(template.id);
    }

    // Also invalidate global cache since day data changed
    _streakCache.remove('global_logging_streak');

    // Recalculate affected streaks
    for (final template in affectedTemplates) {
      await updateTaskStreak(template);
    }
    await updateGlobalLoggingStreak();
  }

  /// Template configuration changed - invalidate and recalculate
  Future<void> onTemplateConfigChanged(TaskTemplate template) async {
    invalidateCache(template.id);
    await updateTaskStreak(template);
  }

  /// Bulk recalculation with smart caching
  Future<void> recalculateAllStreaks(List<TaskTemplate> templates) async {
    // Check if we really need to recalculate
    bool needsRecalc = false;

    for (final template in templates) {
      final cacheKey = '${template.id}_${template.lastModified.millisecondsSinceEpoch}';
      if (!_streakCache.containsKey(cacheKey)) {
        needsRecalc = true;
        break;
      }
    }

    if (!needsRecalc && _streakCache.containsKey('global_logging_streak')) {
      if (kDebugMode) print('Streaks are up to date, skipping recalculation');
      return;
    }

    if (kDebugMode) print('Recalculating streaks for ${templates.length} templates...');

    for (final template in templates) {
      await updateTaskStreak(template);
    }
    await updateGlobalLoggingStreak();

    if (kDebugMode) print('Streak recalculation completed');
  }

  /// Cleanup old cache entries to prevent memory leaks
  void _cleanupCache() {
    if (_streakCache.length > 100) { // Arbitrary limit
      // Keep only recent entries
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      _streakCache.removeWhere((key, streak) =>
          streak.lastCalculated != null &&
          streak.lastCalculated!.isBefore(cutoff));

      if (kDebugMode) print('Cleaned up old cache entries. Current size: ${_streakCache.length}');
    }
  }

  /// Performance monitoring method
  void logPerformanceStats() {
    if (kDebugMode) {
      print('=== StreakService Performance Stats ===');
      print('Cache entries: ${_streakCache.length}');
      print('Indexed days: ${_dayIndex?.length ?? 0}');
      print('Day-template mappings: ${_tasksByDayAndTemplate?.length ?? 0}');
      print('Indexes dirty: $_indexesDirty');
      print('====================================');
    }
  }

  void dispose() {
    _streakCache.clear();
    _templateVersions.clear();
    _dayIndex = null;
    _tasksByDayAndTemplate = null;
  }
}