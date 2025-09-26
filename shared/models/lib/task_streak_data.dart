import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'task_streak_data.g.dart';

/// Tracks streak information for tasks and templates
/// Used for both individual task streaks and global logging streaks
@JsonSerializable()
class TaskStreakData extends Equatable {
  /// Current consecutive streak count
  final int currentStreak;

  /// Best (longest) streak ever achieved
  final int bestStreak;

  /// Date of the last completed task
  final DateTime? lastCompletedDate;

  /// Total number of completed tasks
  final int totalCompletions;

  /// When this streak data was last calculated
  final DateTime? lastCalculated;

  /// When the current streak started
  final DateTime? currentStreakStartDate;

  /// Flag indicating that a full recalculation is needed
  /// Set when template configuration changes significantly
  final bool needsRecalculation;

  const TaskStreakData({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    this.totalCompletions = 0,
    this.lastCalculated,
    this.currentStreakStartDate,
    this.needsRecalculation = false,
  });

  /// Factory constructor for JSON deserialization
  factory TaskStreakData.fromJson(Map<String, dynamic> json) =>
      _$TaskStreakDataFromJson(json);

  /// Converts this streak data to JSON for serialization
  Map<String, dynamic> toJson() => _$TaskStreakDataToJson(this);

  /// Creates a copy of this streak data with updated fields
  TaskStreakData copyWith({
    int? currentStreak,
    int? bestStreak,
    DateTime? lastCompletedDate,
    int? totalCompletions,
    DateTime? lastCalculated,
    DateTime? currentStreakStartDate,
    bool? needsRecalculation,
  }) {
    return TaskStreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      lastCalculated: lastCalculated ?? this.lastCalculated,
      currentStreakStartDate: currentStreakStartDate ?? this.currentStreakStartDate,
      needsRecalculation: needsRecalculation ?? this.needsRecalculation,
    );
  }

  /// Factory for creating initial streak data
  factory TaskStreakData.initial() {
    return const TaskStreakData();
  }

  /// Factory for creating streak data that needs recalculation
  factory TaskStreakData.needsRecalculation() {
    return const TaskStreakData(needsRecalculation: true);
  }

  /// Updates streak data with a new completion
  TaskStreakData addCompletion({
    required DateTime completionDate,
    required bool isConsecutive,
  }) {
    final newTotalCompletions = totalCompletions + 1;
    final now = DateTime.now();

    int newCurrentStreak;
    DateTime? newCurrentStreakStartDate;

    if (isConsecutive) {
      newCurrentStreak = currentStreak + 1;
      newCurrentStreakStartDate = currentStreakStartDate ?? completionDate;
    } else {
      newCurrentStreak = 1;
      newCurrentStreakStartDate = completionDate;
    }

    final newBestStreak = newCurrentStreak > bestStreak
        ? newCurrentStreak
        : bestStreak;

    return copyWith(
      currentStreak: newCurrentStreak,
      bestStreak: newBestStreak,
      lastCompletedDate: completionDate,
      totalCompletions: newTotalCompletions,
      lastCalculated: now,
      currentStreakStartDate: newCurrentStreakStartDate,
      needsRecalculation: false,
    );
  }

  /// Breaks the current streak
  TaskStreakData breakStreak() {
    return copyWith(
      currentStreak: 0,
      currentStreakStartDate: null,
      lastCalculated: DateTime.now(),
      needsRecalculation: false,
    );
  }

  /// Marks this streak data as needing recalculation
  TaskStreakData markForRecalculation() {
    return copyWith(needsRecalculation: true);
  }

  /// Whether this streak data is considered fresh/up-to-date
  bool get isFresh {
    if (needsRecalculation) return false;
    if (lastCalculated == null) return false;

    // Consider fresh if calculated within the last hour
    final now = DateTime.now();
    return now.difference(lastCalculated!).inHours < 1;
  }

  /// Human-readable streak summary
  String get summary {
    if (currentStreak == 0) {
      return totalCompletions > 0
          ? 'Streak quebrada - Melhor: $bestStreak dias'
          : 'Nenhuma conclusão ainda';
    }

    return 'Streak atual: $currentStreak dias (Melhor: $bestStreak)';
  }

  @override
  List<Object?> get props => [
    currentStreak,
    bestStreak,
    lastCompletedDate,
    totalCompletions,
    lastCalculated,
    currentStreakStartDate,
    needsRecalculation,
  ];
}