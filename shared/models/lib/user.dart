import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'user.g.dart';

/// Represents a user in the Apogee system
/// Contains gamification data and sync information
@JsonSerializable()
class User extends Equatable {
  /// Unique identifier for this user
  final String id;

  /// User's email address (used for authentication)
  final String email;

  /// Display name
  final String displayName;

  /// Gamification currencies and progression
  final int baseXP;           // XP accumulated until yesterday
  final int todayXP;          // Raw XP earned today
  final int tomorrowXP;       // Raw XP earned during 0-2 AM gap period
  final int coins;            // Earned from completing tasks
  final int diamonds;         // Earned from leveling up
  final int level;            // Current user level

  /// Streak tracking
  final int currentStreak;    // Current consecutive days with all tasks completed
  final int maxStreak;        // Best streak ever achieved

  /// Account management
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final DateTime lastXpReset; // Last time XP was reset at 2 AM

  /// Sync management
  final DateTime lastSyncAt;
  final String deviceId;      // Identifies which device last synced
  final int syncVersion;      // Incremented on each change for conflict resolution

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.baseXP = 0,
    this.todayXP = 0,
    this.tomorrowXP = 0,
    this.coins = 0,
    this.diamonds = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.maxStreak = 0,
    required this.createdAt,
    required this.lastLoginAt,
    required this.lastXpReset,
    required this.lastSyncAt,
    required this.deviceId,
    this.syncVersion = 1,
  });

  /// Factory constructor for JSON deserialization
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Converts this user to JSON for serialization
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Creates a copy of this user with updated fields
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    int? baseXP,
    int? todayXP,
    int? tomorrowXP,
    int? coins,
    int? diamonds,
    int? level,
    int? currentStreak,
    int? maxStreak,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastXpReset,
    DateTime? lastSyncAt,
    String? deviceId,
    int? syncVersion,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      baseXP: baseXP ?? this.baseXP,
      todayXP: todayXP ?? this.todayXP,
      tomorrowXP: tomorrowXP ?? this.tomorrowXP,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastXpReset: lastXpReset ?? this.lastXpReset,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      deviceId: deviceId ?? this.deviceId,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  /// Factory for creating a new user
  factory User.create({
    required String email,
    required String displayName,
    required String deviceId,
  }) {
    final now = DateTime.now();
    final id = 'user_${now.millisecondsSinceEpoch}';

    return User(
      id: id,
      email: email,
      displayName: displayName,
      createdAt: now,
      lastLoginAt: now,
      lastXpReset: now,
      lastSyncAt: now,
      deviceId: deviceId,
    );
  }

  /// Calculates real today XP with 200 XP cap and 25% overflow
  int get realTodayXP {
    const cap = 200;
    if (todayXP <= cap) return todayXP;
    return cap + ((todayXP - cap) * 0.25).round();
  }

  /// Calculates real tomorrow XP with 200 XP cap and 25% overflow
  int get realTomorrowXP {
    const cap = 200;
    if (tomorrowXP <= cap) return tomorrowXP;
    return cap + ((tomorrowXP - cap) * 0.25).round();
  }

  /// Total XP including all sources
  int get totalXP => baseXP + realTodayXP + realTomorrowXP;

  /// XP required for the next level
  int get requiredXPForNextLevel {
    return level * level * 100; // (level)^2 * 100
  }

  /// XP required for the current level
  int get requiredXPForCurrentLevel {
    return (level - 1) * (level - 1) * 100;
  }

  /// Progress towards next level (0.0 to 1.0)
  double get levelProgress {
    final currentLevelXP = requiredXPForCurrentLevel;
    final nextLevelXP = requiredXPForNextLevel;
    final progressXP = totalXP - currentLevelXP;
    final neededXP = nextLevelXP - currentLevelXP;

    if (neededXP <= 0) return 1.0;
    return (progressXP / neededXP).clamp(0.0, 1.0);
  }

  /// Whether this user needs XP reset (past 2 AM)
  bool get needsXPReset {
    final now = DateTime.now();

    // Calculate the current "day" based on 2 AM cutoff
    final currentDay = now.hour >= 2
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day - 1);

    final lastResetDay = DateTime(
      lastXpReset.year,
      lastXpReset.month,
      lastXpReset.day,
    );

    return lastResetDay.isBefore(currentDay);
  }

  /// Creates an updated user with incremented sync version
  User incrementSyncVersion({required String deviceId}) {
    return copyWith(
      syncVersion: syncVersion + 1,
      lastSyncAt: DateTime.now(),
      deviceId: deviceId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    baseXP,
    todayXP,
    tomorrowXP,
    coins,
    diamonds,
    level,
    currentStreak,
    maxStreak,
    createdAt,
    lastLoginAt,
    lastXpReset,
    lastSyncAt,
    deviceId,
    syncVersion,
  ];
}