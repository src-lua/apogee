import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/enums/task_status.dart';

class LevelUpResult {
  final int oldLevel;
  final int newLevel;
  final int diamondsAwarded;

  LevelUpResult({
    required this.oldLevel,
    required this.newLevel,
    required this.diamondsAwarded,
  });
}

class PointsResult {
  final int xpApplied;
  final LevelUpResult? levelUpResult;

  PointsResult({
    required this.xpApplied,
    this.levelUpResult,
  });
}

class UserService {
  late final Box _dataBox;
  static const String _userPointsKey = 'userPoints'; // XP until yesterday
  static const String _userCoinsKey = 'userCoins';
  static const String _userDiamondsKey = 'userDiamonds';
  static const String _userLevelKey = 'userLevel';
  static const String _userStreakKey = 'userStreak';
  static const String _userMaxStreakKey = 'userMaxStreak';
  static const String _todayXpKey = 'todayXp'; // Sum of all XP earned today
  static const String _tomorrowXpKey = 'tomorrowXp'; // Sum of all XP earned tomorrow (during 0-2 AM gap)
  static const String _lastXpResetKey = 'lastXpReset';

  UserService._();
  static final UserService _instance = UserService._();
  static UserService get instance => _instance;

  Future<void> initialize() async {
    _dataBox = Hive.box('apogee_data');
  }

  int getUserPoints() {
    try {
      _checkDailyXpReset();
      return getTotalXP();
    } catch (e) {
      if (kDebugMode) print('Error loading user points: $e');
      return 0;
    }
  }

  int getBaseXP() {
    try {
      return _dataBox.get(_userPointsKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading base XP: $e');
      return 0;
    }
  }

  int getTodayXP() {
    try {
      _checkDailyXpReset();
      return _dataBox.get(_todayXpKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading today XP: $e');
      return 0;
    }
  }

  int getTomorrowXP() {
    try {
      _checkDailyXpReset();
      return _dataBox.get(_tomorrowXpKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading tomorrow XP: $e');
      return 0;
    }
  }

  int getRealTodayXP() {
    final todayXP = getTodayXP();
    const cap = 200;

    if (todayXP <= cap) {
      return todayXP;
    } else {
      return cap + ((todayXP - cap) * 0.25).round();
    }
  }

  int getRealTomorrowXP() {
    final tomorrowXP = getTomorrowXP();
    const cap = 200;

    if (tomorrowXP <= cap) {
      return tomorrowXP;
    } else {
      return cap + ((tomorrowXP - cap) * 0.25).round();
    }
  }

  int getTotalXP() {
    return getBaseXP() + getRealTodayXP() + getRealTomorrowXP();
  }

  int getUserCoins() {
    try {
      return _dataBox.get(_userCoinsKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading user coins: $e');
      return 0;
    }
  }

  int getUserDiamonds() {
    try {
      return _dataBox.get(_userDiamondsKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading user diamonds: $e');
      return 0;
    }
  }

  int getUserLevel() {
    try {
      return _dataBox.get(_userLevelKey, defaultValue: 1);
    } catch (e) {
      if (kDebugMode) print('Error loading user level: $e');
      return 1;
    }
  }

  int getUserStreak() {
    try {
      return _dataBox.get(_userStreakKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading user streak: $e');
      return 0;
    }
  }

  int getUserMaxStreak() {
    try {
      return _dataBox.get(_userMaxStreakKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading user max streak: $e');
      return 0;
    }
  }

  int getDailyXpLimit() {
    return 200;
  }

  Future<PointsResult> addPoints(int points, DateTime taskDay) async {
    try {
      _checkDailyXpReset();

      final now = DateTime.now();
      final isInGapPeriod = now.hour < 2; // Between 0 AM and 2 AM

      // Determine which XP pool to add to
      if (isInGapPeriod) {
        // During gap period: check if task is from "yesterday" or "today"
        final currentXpDay = now.hour >= 2
            ? DateTime(now.year, now.month, now.day)
            : DateTime(now.year, now.month, now.day - 1);

        final normalizedTaskDay = DateTime(taskDay.year, taskDay.month, taskDay.day);

        if (normalizedTaskDay.isAtSameMomentAs(currentXpDay)) {
          // Task from "yesterday" -> current limit
          final currentTodayXP = getTodayXP();
          await _dataBox.put(_todayXpKey, currentTodayXP + points);
        } else {
          // Task from "today" -> tomorrow's limit
          final currentTomorrowXP = getTomorrowXP();
          await _dataBox.put(_tomorrowXpKey, currentTomorrowXP + points);
        }
      } else {
        // Normal period: always add to today
        final currentTodayXP = getTodayXP();
        await _dataBox.put(_todayXpKey, currentTodayXP + points);
      }

      // Check for level up with new total
      final newTotalXP = getTotalXP();
      final levelUpResult = await _checkLevelUp(newTotalXP);

      return PointsResult(
        xpApplied: points,
        levelUpResult: levelUpResult,
      );
    } catch (e) {
      if (kDebugMode) print('Error adding points: $e');
      rethrow;
    }
  }

  Future<int> removePoints(int points, DateTime taskDay) async {
    try {
      _checkDailyXpReset();

      final now = DateTime.now();
      final isInGapPeriod = now.hour < 2; // Between 0 AM and 2 AM

      // Determine which XP pool to remove from
      if (isInGapPeriod) {
        // During gap period: check if task is from "yesterday" or "today"
        final currentXpDay = now.hour >= 2
            ? DateTime(now.year, now.month, now.day)
            : DateTime(now.year, now.month, now.day - 1);

        final normalizedTaskDay = DateTime(taskDay.year, taskDay.month, taskDay.day);

        if (normalizedTaskDay.isAtSameMomentAs(currentXpDay)) {
          // Task from "yesterday" -> current limit
          final currentTodayXP = getTodayXP();
          final newTodayXP = (currentTodayXP - points).clamp(0, double.infinity).toInt();
          await _dataBox.put(_todayXpKey, newTodayXP);
        } else {
          // Task from "today" -> tomorrow's limit
          final currentTomorrowXP = getTomorrowXP();
          final newTomorrowXP = (currentTomorrowXP - points).clamp(0, double.infinity).toInt();
          await _dataBox.put(_tomorrowXpKey, newTomorrowXP);
        }
      } else {
        // Normal period: always remove from today
        final currentTodayXP = getTodayXP();
        final newTodayXP = (currentTodayXP - points).clamp(0, double.infinity).toInt();
        await _dataBox.put(_todayXpKey, newTodayXP);
      }

      return points; // Return the points attempted to remove
    } catch (e) {
      if (kDebugMode) print('Error removing points: $e');
      rethrow;
    }
  }

  Future<void> addCoins(int coins) async {
    try {
      final currentCoins = getUserCoins();
      await _dataBox.put(_userCoinsKey, currentCoins + coins);
    } catch (e) {
      if (kDebugMode) print('Error adding coins: $e');
      rethrow;
    }
  }

  Future<void> removeCoins(int coins) async {
    try {
      final currentCoins = getUserCoins();
      final newCoins = (currentCoins - coins).clamp(0, double.infinity).toInt();
      await _dataBox.put(_userCoinsKey, newCoins);
    } catch (e) {
      if (kDebugMode) print('Error removing coins: $e');
      rethrow;
    }
  }

  Future<void> addDiamonds(int diamonds) async {
    try {
      final currentDiamonds = getUserDiamonds();
      await _dataBox.put(_userDiamondsKey, currentDiamonds + diamonds);
    } catch (e) {
      if (kDebugMode) print('Error adding diamonds: $e');
      rethrow;
    }
  }

  Future<bool> spendCoins(int coins) async {
    final currentCoins = getUserCoins();
    if (currentCoins >= coins) {
      await removeCoins(coins);
      return true;
    }
    return false;
  }

  Future<bool> spendDiamonds(int diamonds) async {
    final currentDiamonds = getUserDiamonds();
    if (currentDiamonds >= diamonds) {
      try {
        final newDiamonds = (currentDiamonds - diamonds).clamp(0, double.infinity).toInt();
        await _dataBox.put(_userDiamondsKey, newDiamonds);
        return true;
      } catch (e) {
        if (kDebugMode) print('Error spending diamonds: $e');
        return false;
      }
    }
    return false;
  }

  Future<LevelUpResult?> _checkLevelUp(int currentPoints) async {
    final currentLevel = getUserLevel();
    final requiredPointsForNextLevel = _getRequiredPointsForLevel(currentLevel + 1);

    if (currentPoints >= requiredPointsForNextLevel) {
      final newLevel = currentLevel + 1;
      await _dataBox.put(_userLevelKey, newLevel);

      // Award diamonds for leveling up
      final diamondsReward = newLevel; // 1 diamond per level
      await addDiamonds(diamondsReward);

      if (kDebugMode) print('Level up! New level: $newLevel, Diamonds awarded: $diamondsReward');

      return LevelUpResult(
        oldLevel: currentLevel,
        newLevel: newLevel,
        diamondsAwarded: diamondsReward,
      );
    }
    return null;
  }

  int _getRequiredPointsForLevel(int level) {
    // Progressive XP requirement: (level-1)^2 * 100
    return (level - 1) * (level - 1) * 100;
  }

  int getRequiredPointsForNextLevel() {
    final currentLevel = getUserLevel();
    return _getRequiredPointsForLevel(currentLevel + 1);
  }

  double getLevelProgress() {
    final currentPoints = getUserPoints();
    final currentLevel = getUserLevel();
    final currentLevelPoints = _getRequiredPointsForLevel(currentLevel);
    final nextLevelPoints = _getRequiredPointsForLevel(currentLevel + 1);

    final pointsInCurrentLevel = currentPoints - currentLevelPoints;
    final pointsNeededForLevel = nextLevelPoints - currentLevelPoints;

    return (pointsInCurrentLevel / pointsNeededForLevel).clamp(0.0, 1.0);
  }

  Future<void> updateStreakForDay(List<Task> tasks) async {
    try {
      // Check if all tasks are non-pending
      final allTasksCompleted = tasks.isNotEmpty && tasks.every((task) => task.status != TaskStatus.pending);

      if (!allTasksCompleted) {
        // Not all tasks completed, don't update streak
        return;
      }

      // Check if any task was completed late
      final hasLateCompletion = tasks.any((task) => task.isLate);

      final currentStreak = getUserStreak();
      final maxStreak = getUserMaxStreak();

      if (hasLateCompletion) {
        // Late completion breaks the streak
        await _dataBox.put(_userStreakKey, 0);
      } else {
        // All tasks completed on time - maintain or increase streak
        final newStreak = currentStreak + 1;
        await _dataBox.put(_userStreakKey, newStreak);

        // Update max streak if needed
        if (newStreak > maxStreak) {
          await _dataBox.put(_userMaxStreakKey, newStreak);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error updating streak: $e');
    }
  }

  void _checkDailyXpReset() {
    try {
      final now = DateTime.now();

      // Calculate the current "day" based on 2 AM cutoff
      // If it's before 2 AM, we're still in the previous day
      final currentDay = now.hour >= 2
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month, now.day - 1);

      final lastResetDate = _dataBox.get(_lastXpResetKey);
      final lastResetDay = lastResetDate != null
          ? DateTime.parse(lastResetDate)
          : null;

      if (lastResetDay == null || lastResetDay.isBefore(currentDay)) {
        // Shift XP values: base += real_today, today = tomorrow, tomorrow = 0
        final realTodayXP = getRealTodayXP();
        final currentBaseXP = getBaseXP();
        final currentTomorrowXP = getTomorrowXP();

        // base XP += real today XP
        _dataBox.put(_userPointsKey, currentBaseXP + realTodayXP);

        // today XP = tomorrow XP
        _dataBox.put(_todayXpKey, currentTomorrowXP);

        // tomorrow XP = 0
        _dataBox.put(_tomorrowXpKey, 0);

        _dataBox.put(_lastXpResetKey, currentDay.toIso8601String());
      }
    } catch (e) {
      if (kDebugMode) print('Error checking daily XP reset: $e');
    }
  }

  void dispose() {
    // Box is managed by main app, so we don't close it here
  }
}