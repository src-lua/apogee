import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import 'package:apogee_shared/user.dart';
import 'package:apogee_shared/task.dart';
import 'package:apogee_shared/task_template.dart';
import 'package:apogee_shared/task_streak_data.dart';

/// Database service handling PostgreSQL operations
/// Provides data access layer for all entities with type-safe queries
class DatabaseService {
  static Connection? _connection;
  static bool _isInitialized = false;
  static DotEnv? _env;

  /// Initialize environment configuration
  static void initializeEnv() {
    _env = DotEnv(includePlatformEnvironment: true)..load();
  }

  /// PostgreSQL connection configuration from environment
  static Endpoint get _endpoint {
    final env = _env ?? (DotEnv(includePlatformEnvironment: true)..load());
    final host = env['DB_HOST'] ?? 'localhost';
    final port = int.parse(env['DB_PORT'] ?? '5432');
    final database = env['DB_NAME'] ?? 'apogee';
    final username = env['DB_USER'] ?? 'postgres';
    final password = env['DB_PASSWORD'] ?? 'password';

    return Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }

  /// Initialize database connection and create tables
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize environment if not already done
    if (_env == null) {
      initializeEnv();
    }

    try {
      _connection = await Connection.open(
        _endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );

      // Create database schema
      await _createTables();
      await _createIndexes();

      _isInitialized = true;
      print('PostgreSQL database connected successfully');
    } catch (e) {
      print('Failed to connect to PostgreSQL database: $e');
      rethrow;
    }
  }

  /// Get database connection
  static Connection get database {
    if (!_isInitialized || _connection == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _connection!;
  }

  /// Close database connection
  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _isInitialized = false;
    }
  }

  // User operations

  /// Create a new user with hashed password
  static Future<void> createUser(User user, String hashedPassword) async {
    final db = database;

    await db.runTx((session) async {
      // Insert user data
      await session.execute(
        Sql.named('''
          INSERT INTO users (
            id, email, display_name, base_xp, today_xp, tomorrow_xp,
            coins, diamonds, level, current_streak, max_streak,
            created_at, last_login_at, last_xp_reset, last_sync_at,
            device_id, sync_version
          ) VALUES (
            @id, @email, @displayName, @baseXP, @todayXP, @tomorrowXP,
            @coins, @diamonds, @level, @currentStreak, @maxStreak,
            @createdAt, @lastLoginAt, @lastXpReset, @lastSyncAt,
            @deviceId, @syncVersion
          )
        '''),
        parameters: {
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'baseXP': user.baseXP,
          'todayXP': user.todayXP,
          'tomorrowXP': user.tomorrowXP,
          'coins': user.coins,
          'diamonds': user.diamonds,
          'level': user.level,
          'currentStreak': user.currentStreak,
          'maxStreak': user.maxStreak,
          'createdAt': user.createdAt,
          'lastLoginAt': user.lastLoginAt,
          'lastXpReset': user.lastXpReset,
          'lastSyncAt': user.lastSyncAt,
          'deviceId': user.deviceId,
          'syncVersion': user.syncVersion,
        },
      );

      // Insert authentication data separately for security
      await session.execute(
        Sql.named('''
          INSERT INTO user_auth (user_id, email, password_hash, created_at)
          VALUES (@userId, @email, @passwordHash, @createdAt)
        '''),
        parameters: {
          'userId': user.id,
          'email': user.email,
          'passwordHash': hashedPassword,
          'createdAt': DateTime.now(),
        },
      );
    });
  }

  /// Find user by ID
  static Future<User?> findUserById(String userId) async {
    final db = database;

    final result = await db.execute(
      Sql.named('SELECT * FROM users WHERE id = @userId'),
      parameters: {'userId': userId},
    );

    if (result.isEmpty) return null;

    return _userFromRow(result.first);
  }

  /// Find user by email
  static Future<User?> findUserByEmail(String email) async {
    final db = database;

    final result = await db.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email},
    );

    if (result.isEmpty) return null;

    return _userFromRow(result.first);
  }

  /// Find user by email with password hash (for authentication)
  static Future<Map<String, dynamic>?> findUserByEmailWithPassword(String email) async {
    final db = database;

    final userResult = await db.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email},
    );

    if (userResult.isEmpty) return null;

    final authResult = await db.execute(
      Sql.named('SELECT password_hash FROM user_auth WHERE email = @email'),
      parameters: {'email': email},
    );

    if (authResult.isEmpty) return null;

    return {
      'user': _userFromRow(userResult.first),
      'password': authResult.first[0] as String,
    };
  }

  /// Update user data
  static Future<void> updateUser(User user) async {
    final db = database;

    await db.execute(
      Sql.named('''
        UPDATE users SET
          display_name = @displayName, base_xp = @baseXP, today_xp = @todayXP,
          tomorrow_xp = @tomorrowXP, coins = @coins, diamonds = @diamonds,
          level = @level, current_streak = @currentStreak, max_streak = @maxStreak,
          last_login_at = @lastLoginAt, last_xp_reset = @lastXpReset,
          last_sync_at = @lastSyncAt, device_id = @deviceId, sync_version = @syncVersion
        WHERE id = @id
      '''),
      parameters: {
        'id': user.id,
        'displayName': user.displayName,
        'baseXP': user.baseXP,
        'todayXP': user.todayXP,
        'tomorrowXP': user.tomorrowXP,
        'coins': user.coins,
        'diamonds': user.diamonds,
        'level': user.level,
        'currentStreak': user.currentStreak,
        'maxStreak': user.maxStreak,
        'lastLoginAt': user.lastLoginAt,
        'lastXpReset': user.lastXpReset,
        'lastSyncAt': user.lastSyncAt,
        'deviceId': user.deviceId,
        'syncVersion': user.syncVersion,
      },
    );
  }

  /// Update user password
  static Future<void> updateUserPassword(String userId, String hashedPassword) async {
    final db = database;

    await db.execute(
      Sql.named('UPDATE user_auth SET password_hash = @passwordHash WHERE user_id = @userId'),
      parameters: {
        'userId': userId,
        'passwordHash': hashedPassword,
      },
    );
  }

  // Task Template operations

  /// Create a new task template
  static Future<void> createTaskTemplate(TaskTemplate template) async {
    final db = database;

    await db.execute(
      Sql.named('''
        INSERT INTO task_templates (
          id, name, coins, user_id, recurrency_type, custom_days,
          is_active, created_at, last_modified, last_generated,
          start_date, end_date, streak_data
        ) VALUES (
          @id, @name, @coins, @userId, @recurrencyType, @customDays,
          @isActive, @createdAt, @lastModified, @lastGenerated,
          @startDate, @endDate, @streakData
        )
      '''),
      parameters: {
        'id': template.id,
        'name': template.name,
        'coins': template.coins,
        'userId': template.userId,
        'recurrencyType': template.recurrencyType.name,
        'customDays': template.customDays,
        'isActive': template.isActive,
        'createdAt': template.createdAt,
        'lastModified': template.lastModified,
        'lastGenerated': template.lastGenerated,
        'startDate': template.startDate,
        'endDate': template.endDate,
        'streakData': template.streakData.toJson(),
      },
    );
  }

  /// Find task templates by user ID
  static Future<List<TaskTemplate>> findTaskTemplatesByUserId(String userId) async {
    final db = database;

    final result = await db.execute(
      Sql.named('SELECT * FROM task_templates WHERE user_id = @userId ORDER BY created_at DESC'),
      parameters: {'userId': userId},
    );

    return result.map(_taskTemplateFromRow).toList();
  }

  /// Find task template by ID
  static Future<TaskTemplate?> findTaskTemplateById(String templateId) async {
    final db = database;

    final result = await db.execute(
      Sql.named('SELECT * FROM task_templates WHERE id = @templateId'),
      parameters: {'templateId': templateId},
    );

    if (result.isEmpty) return null;

    return _taskTemplateFromRow(result.first);
  }

  /// Update task template
  static Future<void> updateTaskTemplate(TaskTemplate template) async {
    final db = database;

    await db.execute(
      Sql.named('''
        UPDATE task_templates SET
          name = @name, coins = @coins, recurrency_type = @recurrencyType,
          custom_days = @customDays, is_active = @isActive, last_modified = @lastModified,
          last_generated = @lastGenerated, start_date = @startDate, end_date = @endDate,
          streak_data = @streakData
        WHERE id = @id
      '''),
      parameters: {
        'id': template.id,
        'name': template.name,
        'coins': template.coins,
        'recurrencyType': template.recurrencyType.name,
        'customDays': template.customDays,
        'isActive': template.isActive,
        'lastModified': template.lastModified,
        'lastGenerated': template.lastGenerated,
        'startDate': template.startDate,
        'endDate': template.endDate,
        'streakData': template.streakData.toJson(),
      },
    );
  }

  /// Delete task template
  static Future<void> deleteTaskTemplate(String templateId) async {
    final db = database;

    await db.execute(
      Sql.named('DELETE FROM task_templates WHERE id = @templateId'),
      parameters: {'templateId': templateId},
    );
  }

  // Helper methods for converting database rows to objects

  /// Convert database row to User object
  static User _userFromRow(List<dynamic> row) {
    return User(
      id: row[0] as String,
      email: row[1] as String,
      displayName: row[2] as String,
      baseXP: row[3] as int,
      todayXP: row[4] as int,
      tomorrowXP: row[5] as int,
      coins: row[6] as int,
      diamonds: row[7] as int,
      level: row[8] as int,
      currentStreak: row[9] as int,
      maxStreak: row[10] as int,
      createdAt: row[11] as DateTime,
      lastLoginAt: row[12] as DateTime,
      lastXpReset: row[13] as DateTime,
      lastSyncAt: row[14] as DateTime,
      deviceId: row[15] as String,
      syncVersion: row[16] as int,
    );
  }

  /// Convert database row to TaskTemplate object
  static TaskTemplate _taskTemplateFromRow(List<dynamic> row) {
    // This is a simplified version - you'd need to properly handle JSON parsing
    // for custom_days and streak_data fields
    return TaskTemplate(
      id: row[0] as String,
      name: row[1] as String,
      coins: row[2] as int,
      userId: row[3] as String,
      // recurrencyType: RecurrencyType.values.byName(row[4] as String),
      // Additional field parsing would go here...
      createdAt: row[6] as DateTime,
      lastModified: row[7] as DateTime,
      streakData: const TaskStreakData(), // Placeholder
    );
  }

  /// Create database tables
  static Future<void> _createTables() async {
    final db = _connection!;

    // Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        display_name VARCHAR(255) NOT NULL,
        base_xp INTEGER DEFAULT 0,
        today_xp INTEGER DEFAULT 0,
        tomorrow_xp INTEGER DEFAULT 0,
        coins INTEGER DEFAULT 0,
        diamonds INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        current_streak INTEGER DEFAULT 0,
        max_streak INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL,
        last_login_at TIMESTAMP WITH TIME ZONE NOT NULL,
        last_xp_reset TIMESTAMP WITH TIME ZONE NOT NULL,
        last_sync_at TIMESTAMP WITH TIME ZONE NOT NULL,
        device_id VARCHAR(255) NOT NULL,
        sync_version INTEGER DEFAULT 1
      )
    ''');

    // User authentication table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_auth (
        user_id VARCHAR(255) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL
      )
    ''');

    // Task templates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_templates (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        coins INTEGER NOT NULL,
        user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        recurrency_type VARCHAR(50) NOT NULL,
        custom_days INTEGER[],
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL,
        last_modified TIMESTAMP WITH TIME ZONE NOT NULL,
        last_generated TIMESTAMP WITH TIME ZONE,
        start_date TIMESTAMP WITH TIME ZONE,
        end_date TIMESTAMP WITH TIME ZONE,
        streak_data JSONB NOT NULL
      )
    ''');

    // Tasks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        coins INTEGER NOT NULL,
        status VARCHAR(50) NOT NULL DEFAULT 'pending',
        completed_at TIMESTAMP WITH TIME ZONE,
        is_late BOOLEAN DEFAULT false,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
        template_id VARCHAR(255) NOT NULL REFERENCES task_templates(id) ON DELETE CASCADE,
        scheduled_date DATE NOT NULL
      )
    ''');

    print('Database tables created successfully');
  }

  /// Create database indexes for better performance
  static Future<void> _createIndexes() async {
    final db = _connection!;

    // User indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');

    // Task template indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_task_templates_user_id ON task_templates(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_task_templates_user_active ON task_templates(user_id, is_active)');

    // Task indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_template_id ON tasks(template_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_date ON tasks(scheduled_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_template_date ON tasks(template_id, scheduled_date)');

    print('Database indexes created successfully');
  }
}