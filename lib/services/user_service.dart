import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/enums/task_status.dart';

class UserService {
  late final Box _dataBox;
  static const String _userPointsKey = 'userPoints';
  static const String _userCoinsKey = 'userCoins';
  static const String _userDiamondsKey = 'userDiamonds';
  static const String _userLevelKey = 'userLevel';
  static const String _userStreakKey = 'userStreak';
  static const String _userMaxStreakKey = 'userMaxStreak';
  static const String _dailyXpEarnedKey = 'dailyXpEarned'; // Total XP earned today (uncapped)
  static const String _dailyXpLostKey = 'dailyXpLost'; // Total XP lost today
  static const String _lastXpResetKey = 'lastXpReset';

  UserService._();
  static final UserService _instance = UserService._();
  static UserService get instance => _instance;

  Future<void> initialize() async {
    _dataBox = Hive.box('apogee_data');
  }

  int getUserPoints() {
    try {
      return _dataBox.get(_userPointsKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading user points: $e');
      return 0;
    }
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

  int getDailyXpEarned() {
    try {
      _checkDailyXpReset();
      return _dataBox.get(_dailyXpEarnedKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading daily earned XP: $e');
      return 0;
    }
  }

  int getDailyXpLost() {
    try {
      _checkDailyXpReset();
      return _dataBox.get(_dailyXpLostKey, defaultValue: 0);
    } catch (e) {
      if (kDebugMode) print('Error loading daily lost XP: $e');
      return 0;
    }
  }

  int getDailyXpNet() {
    // Calculate: min(earned - lost, daily_cap)
    final earned = getDailyXpEarned();
    final lost = getDailyXpLost();
    final net = earned - lost;
    final cap = getDailyXpLimit();
    return net.clamp(0, cap);
  }

  int getDailyXpLimit() {
    // XP limit increases with level: base 100 + (level * 20)
    return 100 + (getUserLevel() * 20);
  }

  Future<int> addPoints(int points) async {
    try {
      _checkDailyXpReset();

      // Calculate previous net XP
      final previousNet = getDailyXpNet();

      // Track earned XP (uncapped)
      final dailyEarned = getDailyXpEarned();
      await _dataBox.put(_dailyXpEarnedKey, dailyEarned + points);

      // Calculate new net XP after this addition
      final newNet = getDailyXpNet();
      final xpToApply = newNet - previousNet;

      if (xpToApply > 0) {
        // Update user's total points
        final currentPoints = getUserPoints();
        final newPoints = currentPoints + xpToApply;
        await _dataBox.put(_userPointsKey, newPoints);

        // Check for level up
        await _checkLevelUp(newPoints);
      }

      return xpToApply; // Return actual XP applied to user's total
    } catch (e) {
      if (kDebugMode) print('Error adding points: $e');
      rethrow;
    }
  }

  Future<int> removePoints(int points) async {
    try {
      _checkDailyXpReset();

      // Calculate previous net XP
      final previousNet = getDailyXpNet();

      // Track lost XP
      final dailyLost = getDailyXpLost();
      await _dataBox.put(_dailyXpLostKey, dailyLost + points);

      // Calculate new net XP after this loss
      final newNet = getDailyXpNet();
      final xpToRemove = previousNet - newNet;

      if (xpToRemove > 0) {
        // Update user's total points
        final currentPoints = getUserPoints();
        final newPoints = (currentPoints - xpToRemove).clamp(0, double.infinity).toInt();
        await _dataBox.put(_userPointsKey, newPoints);
      }

      return xpToRemove; // Return actual XP removed from user's total
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

  Future<void> _checkLevelUp(int currentPoints) async {
    final currentLevel = getUserLevel();
    final requiredPointsForNextLevel = _getRequiredPointsForLevel(currentLevel + 1);

    if (currentPoints >= requiredPointsForNextLevel) {
      final newLevel = currentLevel + 1;
      await _dataBox.put(_userLevelKey, newLevel);

      // Award diamonds for leveling up
      final diamondsReward = newLevel; // 1 diamond per level
      await addDiamonds(diamondsReward);

      if (kDebugMode) print('Level up! New level: $newLevel, Diamonds awarded: $diamondsReward');
    }
  }

  int _getRequiredPointsForLevel(int level) {
    // Progressive XP requirement: level^2 * 100
    return level * level * 100;
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
      final today = DateTime(now.year, now.month, now.day);
      final lastResetDate = _dataBox.get(_lastXpResetKey);

      if (lastResetDate == null || DateTime.parse(lastResetDate).isBefore(today)) {
        // Reset daily counters
        _dataBox.put(_dailyXpEarnedKey, 0);
        _dataBox.put(_dailyXpLostKey, 0);
        _dataBox.put(_lastXpResetKey, today.toIso8601String());
      }
    } catch (e) {
      if (kDebugMode) print('Error checking daily XP reset: $e');
    }
  }

  void dispose() {
    // Box is managed by main app, so we don't close it here
  }
}