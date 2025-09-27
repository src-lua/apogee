# Development Guide

This document covers development best practices, performance considerations, security implementation, and testing strategies for Apogee.

## 📈 Performance Optimization

### Database Performance

#### Index Strategy

```sql
-- Essential indexes for common queries
CREATE INDEX CONCURRENTLY idx_tasks_user_date ON tasks(user_id, date);
CREATE INDEX CONCURRENTLY idx_tasks_template_date ON tasks(template_id, date);
CREATE INDEX CONCURRENTLY idx_tasks_status ON tasks(status) WHERE status != 'completed';
CREATE INDEX CONCURRENTLY idx_user_xp_last_reset ON user_xp(last_reset_date);

-- Composite indexes for complex queries
CREATE INDEX CONCURRENTLY idx_tasks_user_status_date ON tasks(user_id, status, date);
CREATE INDEX CONCURRENTLY idx_sync_metadata_entity ON sync_metadata(entity_type, entity_id);

-- Partial indexes for performance
CREATE INDEX CONCURRENTLY idx_tasks_pending ON tasks(user_id, date)
WHERE status IN ('pending', 'late');

-- JSONB indexes for metadata
CREATE INDEX CONCURRENTLY idx_user_preferences ON users USING gin(preferences);
CREATE INDEX CONCURRENTLY idx_task_metadata ON tasks USING gin(metadata);
```

#### Query Optimization

```dart
// Efficient streak calculation with O(1) lookup
class StreakCache {
  static final Map<String, StreakData> _cache = {};

  static Future<int> getCurrentStreak(String userId) async {
    final cacheKey = 'streak_$userId';
    final cached = _cache[cacheKey];

    if (cached != null && _isValidCache(cached)) {
      return cached.currentStreak;
    }

    final streak = await _calculateStreakFromDB(userId);
    _cache[cacheKey] = StreakData(
      currentStreak: streak,
      lastCalculated: DateTime.now(),
    );

    return streak;
  }

  // Optimized streak calculation using window functions
  static Future<int> _calculateStreakFromDB(String userId) async {
    const query = '''
      WITH daily_completions AS (
        SELECT
          date,
          CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END as completed
        FROM tasks
        WHERE user_id = ?
          AND status = 'completed'
          AND date >= CURRENT_DATE - INTERVAL '100 days'
        GROUP BY date
        ORDER BY date DESC
      ),
      streak_calculation AS (
        SELECT
          date,
          completed,
          SUM(CASE WHEN completed = 0 THEN 1 ELSE 0 END)
            OVER (ORDER BY date DESC ROWS UNBOUNDED PRECEDING) as break_group
        FROM daily_completions
      )
      SELECT COUNT(*) as streak
      FROM streak_calculation
      WHERE break_group = 0 AND completed = 1;
    ''';

    final result = await database.query(query, [userId]);
    return result.first['streak'] as int;
  }
}
```

#### Connection Pooling

```dart
// Database connection management
class DatabasePool {
  static late Pool _pool;

  static Future<void> initialize() async {
    _pool = Pool.builder(
      () => Connection.open(
        Endpoint(
          host: Environment.dbHost,
          port: Environment.dbPort,
          database: Environment.dbName,
          username: Environment.dbUser,
          password: Environment.dbPassword,
        ),
        settings: ConnectionSettings(
          sslMode: SslMode.require,
          connectTimeout: Duration(seconds: 10),
          queryTimeout: Duration(seconds: 30),
        ),
      ),
      settings: PoolSettings(
        minConnections: 2,
        maxConnections: 10,
        connectionTimeout: Duration(seconds: 5),
        idleTimeout: Duration(minutes: 10),
        leakDetectionThreshold: Duration(minutes: 5),
      ),
    );
  }

  static Future<T> withConnection<T>(
    Future<T> Function(Connection) callback,
  ) async {
    final connection = await _pool.acquire();
    try {
      return await callback(connection.use());
    } finally {
      connection.release();
    }
  }
}
```

### Client Performance

#### Flutter Optimizations

```dart
// Efficient widget building with const constructors
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onStatusChanged,
  });

  final Task task;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const TaskStatusIcon(), // const constructor
        title: Text(task.title),
        subtitle: task.notes.isNotEmpty
          ? Text(task.notes, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
        trailing: TaskStatusButton(
          status: task.status,
          onPressed: onStatusChanged,
        ),
      ),
    );
  }
}

// Lazy loading for large task lists
class TaskListView extends StatelessWidget {
  const TaskListView({super.key, required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          onStatusChanged: () => _handleStatusChange(task),
        );
      },
    );
  }
}
```

#### State Management Optimization

```dart
// Efficient state management with selective rebuilds
class TaskProvider extends ChangeNotifier {
  final Map<String, List<Task>> _tasksByDate = {};
  final Set<String> _loadingDates = {};

  List<Task> getTasksForDate(String date) {
    return _tasksByDate[date] ?? [];
  }

  bool isLoadingDate(String date) {
    return _loadingDates.contains(date);
  }

  Future<void> loadTasksForDate(String date, {bool force = false}) async {
    if (!force && _tasksByDate.containsKey(date)) return;
    if (_loadingDates.contains(date)) return;

    _loadingDates.add(date);
    notifyListeners(); // Only notify for loading state

    try {
      final tasks = await taskService.getTasksForDate(date);
      _tasksByDate[date] = tasks;
    } finally {
      _loadingDates.remove(date);
    }

    notifyListeners(); // Notify when data is loaded
  }

  // Selective notification for single task updates
  void updateTask(Task updatedTask) {
    final date = updatedTask.date;
    final tasks = _tasksByDate[date];
    if (tasks == null) return;

    final index = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      tasks[index] = updatedTask;
      // Use more granular notification in real implementation
      notifyListeners();
    }
  }
}
```

#### Memory Management

```dart
// Image caching and memory management
class OptimizedImageWidget extends StatelessWidget {
  const OptimizedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  final String imageUrl;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      placeholder: (context, url) => const ShimmerPlaceholder(),
      errorWidget: (context, url, error) => const ErrorPlaceholder(),
      cacheManager: CustomCacheManager.instance,
    );
  }
}

// Custom cache manager with size limits
class CustomCacheManager extends CacheManager {
  static const key = 'apogee_cache';
  static late CustomCacheManager _instance;

  static CustomCacheManager get instance => _instance;

  static void initialize() {
    _instance = CustomCacheManager._();
  }

  CustomCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
```

## 🔒 Security Implementation

### Authentication Security

#### JWT Token Management

```dart
// Secure JWT implementation with refresh logic
class AuthTokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const Duration _refreshThreshold = Duration(hours: 1);

  static Future<String?> getValidToken() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null) return null;

    final isValid = await _validateToken(token);
    if (isValid) return token;

    // Try to refresh if token is expired
    return await _refreshToken();
  }

  static Future<bool> _validateToken(String token) async {
    try {
      final jwt = JWT.verify(token, SecretKey(Environment.jwtSecret));
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(
        jwt.payload['exp'] * 1000,
      );

      // Check if token expires within threshold
      final timeUntilExpiry = expirationTime.difference(DateTime.now());
      return timeUntilExpiry > _refreshThreshold;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _refreshToken() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;

    try {
      final response = await _apiClient.post('/auth/refresh', {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        await _storeTokens(data['token'], data['refreshToken']);
        return data['token'];
      }
    } catch (e) {
      // Refresh failed, user needs to login again
      await clearTokens();
    }

    return null;
  }
}
```

#### Password Security

```dart
// Server-side password hashing
import 'package:bcrypt/bcrypt.dart';

class PasswordSecurity {
  static const int _saltRounds = 12;

  static String hashPassword(String password) {
    _validatePasswordStrength(password);
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: _saltRounds));
  }

  static bool verifyPassword(String password, String hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }

  static void _validatePasswordStrength(String password) {
    final errors = <String>[];

    if (password.length < 8) {
      errors.add('Password must be at least 8 characters long');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one number');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors.join(', '));
    }
  }
}
```

### Input Validation & Sanitization

```dart
// Comprehensive input validation
class InputValidator {
  static const int maxTaskTitleLength = 100;
  static const int maxTaskNotesLength = 500;
  static const int maxTemplateDescriptionLength = 200;

  static ValidationResult validateTaskUpdate(Map<String, dynamic> data) {
    final errors = <String>[];

    // Validate task status
    if (data.containsKey('status')) {
      final status = data['status'];
      if (!TaskStatus.values.map((e) => e.name).contains(status)) {
        errors.add('Invalid task status: $status');
      }
    }

    // Validate completion time
    if (data.containsKey('completedAt')) {
      final completedAt = data['completedAt'];
      if (completedAt != null) {
        try {
          final dateTime = DateTime.parse(completedAt);
          if (dateTime.isAfter(DateTime.now())) {
            errors.add('Completion time cannot be in the future');
          }
        } catch (e) {
          errors.add('Invalid completion time format');
        }
      }
    }

    // Validate notes
    if (data.containsKey('notes')) {
      final notes = data['notes'] as String?;
      if (notes != null && notes.length > maxTaskNotesLength) {
        errors.add('Notes too long (max $maxTaskNotesLength characters)');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static String sanitizeString(String input) {
    // Remove potentially dangerous characters
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[<>&"\'`]'), '') // Remove dangerous chars
        .trim();
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({required this.isValid, required this.errors});
}
```

### Rate Limiting

```dart
// Rate limiting middleware
class RateLimitMiddleware {
  static final Map<String, List<DateTime>> _requestHistory = {};
  static const int maxRequestsPerMinute = 60;
  static const Duration windowDuration = Duration(minutes: 1);

  static Future<Response> handle(
    RequestContext context,
    Next next,
  ) async {
    final clientId = _getClientId(context);
    final now = DateTime.now();

    // Clean old requests
    _requestHistory[clientId]?.removeWhere(
      (timestamp) => now.difference(timestamp) > windowDuration,
    );

    final requests = _requestHistory[clientId] ?? <DateTime>[];

    if (requests.length >= maxRequestsPerMinute) {
      return Response(
        statusCode: 429,
        headers: {
          'Retry-After': '60',
          'X-RateLimit-Limit': '$maxRequestsPerMinute',
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': '${(now.millisecondsSinceEpoch / 1000 + 60).round()}',
        },
        body: jsonEncode({
          'error': 'Rate limit exceeded',
          'message': 'Too many requests. Try again in 1 minute.',
        }),
      );
    }

    // Record this request
    requests.add(now);
    _requestHistory[clientId] = requests;

    // Add rate limit headers to response
    final response = await next();
    return response.copyWith(
      headers: {
        ...response.headers,
        'X-RateLimit-Limit': '$maxRequestsPerMinute',
        'X-RateLimit-Remaining': '${maxRequestsPerMinute - requests.length}',
      },
    );
  }

  static String _getClientId(RequestContext context) {
    // Use IP address or user ID if authenticated
    final authHeader = context.request.headers['authorization'];
    if (authHeader != null) {
      try {
        final token = authHeader.split(' ')[1];
        final jwt = JWT.verify(token, SecretKey(Environment.jwtSecret));
        return jwt.payload['userId'];
      } catch (e) {
        // Fallback to IP
      }
    }

    return context.request.headers['x-forwarded-for'] ??
           context.request.connectionInfo?.remoteAddress.address ??
           'unknown';
  }
}
```

### SQL Injection Prevention

```dart
// Safe database operations using parameterized queries
class SafeQueryBuilder {
  static Future<List<Task>> getTasksForUser(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // NEVER use string interpolation for SQL
    // ❌ Bad: "SELECT * FROM tasks WHERE user_id = '$userId'"

    // ✅ Good: Use parameterized queries
    const query = '''
      SELECT t.*, tt.title, tt.category
      FROM tasks t
      JOIN task_templates tt ON t.template_id = tt.id
      WHERE t.user_id = $1
        AND t.date >= $2
        AND t.date <= $3
      ORDER BY t.date, tt.title
    ''';

    final result = await database.query(query, [
      userId,
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ]);

    return result.map((row) => Task.fromDatabaseRow(row)).toList();
  }

  static Future<void> updateTaskStatus(
    String taskId,
    String userId,
    TaskStatus status,
    DateTime? completedAt,
  ) async {
    const query = '''
      UPDATE tasks
      SET status = $1, completed_at = $2, updated_at = NOW()
      WHERE id = $3 AND user_id = $4
    ''';

    await database.query(query, [
      status.name,
      completedAt?.toIso8601String(),
      taskId,
      userId,
    ]);
  }
}
```

## 🧪 Testing Strategies

### Unit Testing

#### Model Testing

```dart
// Test XP calculation logic
group('XP Calculation', () {
  test('should calculate correct XP for completed task', () {
    final task = Task(
      id: 'test_task',
      templateId: 'template_1',
      date: '2024-01-01',
      status: TaskStatus.completed,
      completedAt: DateTime(2024, 1, 1, 10, 0),
    );

    final xp = XPCalculator.calculateXP(task);

    expect(xp, equals(20));
  });

  test('should handle XP overflow correctly', () {
    const rawXP = 300;
    final realXP = XPCalculator.calculateRealXP(rawXP);

    expect(realXP, equals(250)); // 200 + (100 * 0.25) = 250
  });

  test('should calculate streak correctly', () {
    final completionDates = [
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 2),
      DateTime(2024, 1, 3),
      // Gap on Jan 4
      DateTime(2024, 1, 5),
      DateTime(2024, 1, 6),
    ];

    final streak = StreakCalculator.calculateCurrentStreak(
      completionDates,
      currentDate: DateTime(2024, 1, 6),
    );

    expect(streak, equals(2)); // Jan 5-6
  });
});
```

#### Service Testing

```dart
// Test sync service with mocks
group('SyncService', () {
  late SyncService syncService;
  late MockApiClient mockApiClient;
  late MockLocalStorage mockLocalStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockLocalStorage = MockLocalStorage();
    syncService = SyncService(
      apiClient: mockApiClient,
      localStorage: mockLocalStorage,
    );
  });

  test('should upload pending changes successfully', () async {
    // Arrange
    final pendingChanges = [
      Change(
        entityType: 'task',
        entityId: 'task_1',
        changeType: 'update',
        data: {'status': 'completed'},
      ),
    ];

    when(mockLocalStorage.getPendingChanges())
        .thenAnswer((_) async => pendingChanges);

    when(mockApiClient.uploadChanges(any))
        .thenAnswer((_) async => SyncResponse(success: true));

    // Act
    final result = await syncService.uploadChanges();

    // Assert
    expect(result.success, isTrue);
    verify(mockLocalStorage.clearPendingChanges()).called(1);
  });

  test('should handle sync conflicts correctly', () async {
    // Arrange
    final localTask = Task(id: 'task_1', status: TaskStatus.completed);
    final serverChange = Change(
      entityId: 'task_1',
      data: {'status': 'pending'},
    );

    when(mockLocalStorage.getEntity('task_1'))
        .thenAnswer((_) async => localTask);

    // Act
    final resolution = await syncService.resolveConflict(
      localTask,
      serverChange,
    );

    // Assert
    expect(resolution.type, equals(ResolutionType.clientWins));
  });
});
```

### Widget Testing

```dart
// Test UI components
group('TaskTile Widget', () {
  testWidgets('should display task information correctly', (tester) async {
    final task = Task(
      id: 'test_task',
      templateId: 'template_1',
      title: 'Morning Exercise',
      status: TaskStatus.pending,
      date: '2024-01-01',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            onStatusChanged: () {},
          ),
        ),
      ),
    );

    expect(find.text('Morning Exercise'), findsOneWidget);
    expect(find.byType(TaskStatusButton), findsOneWidget);
  });

  testWidgets('should call onStatusChanged when button pressed', (tester) async {
    var callbackCalled = false;
    final task = Task(
      id: 'test_task',
      templateId: 'template_1',
      title: 'Test Task',
      status: TaskStatus.pending,
      date: '2024-01-01',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            onStatusChanged: () => callbackCalled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TaskStatusButton));
    await tester.pump();

    expect(callbackCalled, isTrue);
  });
});

// Test state management
group('TaskProvider', () {
  testWidgets('should notify listeners when tasks are loaded', (tester) async {
    final provider = TaskProvider();
    final mockTaskService = MockTaskService();

    when(mockTaskService.getTasksForDate(any))
        .thenAnswer((_) async => [testTask]);

    var notificationCount = 0;
    provider.addListener(() => notificationCount++);

    await provider.loadTasksForDate('2024-01-01');

    expect(notificationCount, equals(2)); // Loading start + data loaded
    expect(provider.getTasksForDate('2024-01-01'), isNotEmpty);
  });
});
```

### Integration Testing

```dart
// Test complete user flows
group('Task Completion Flow', () {
  testWidgets('should complete task and update XP', (tester) async {
    await tester.pumpWidget(MyApp());

    // Navigate to today's tasks
    await tester.tap(find.byKey(Key('today_tab')));
    await tester.pumpAndSettle();

    // Find and tap a pending task
    final taskTile = find.byKey(Key('task_morning_exercise'));
    expect(taskTile, findsOneWidget);

    await tester.tap(taskTile);
    await tester.pumpAndSettle();

    // Mark as completed
    await tester.tap(find.byKey(Key('complete_button')));
    await tester.pumpAndSettle();

    // Verify XP increased
    expect(find.text('XP: 20'), findsOneWidget);

    // Verify task status updated
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
});

// Test API integration
group('API Integration', () {
  testWidgets('should sync data with server', (tester) async {
    // Setup mock server
    final mockServer = MockWebServer();
    mockServer.enqueue(mockResponse: '''
      {
        "success": true,
        "changes": [
          {
            "entityType": "task",
            "entityId": "task_1",
            "data": {"status": "completed"}
          }
        ]
      }
    ''');

    await tester.pumpWidget(MyApp());

    // Trigger sync
    await tester.tap(find.byKey(Key('sync_button')));
    await tester.pumpAndSettle();

    // Verify sync completed
    expect(find.text('Sync completed'), findsOneWidget);

    // Verify API was called
    final request = mockServer.takeRequest();
    expect(request.path, equals('/api/v1/sync/user_123/changes'));
  });
});
```

### Performance Testing

```dart
// Test performance critical operations
group('Performance Tests', () {
  test('XP calculation should complete within time limit', () async {
    final stopwatch = Stopwatch()..start();

    // Simulate calculating XP for 1000 tasks
    for (int i = 0; i < 1000; i++) {
      XPCalculator.calculateRealXP(200 + i);
    }

    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });

  test('streak calculation should handle large datasets', () async {
    final dates = List.generate(365, (index) =>
      DateTime(2024, 1, 1).add(Duration(days: index)));

    final stopwatch = Stopwatch()..start();

    final streak = StreakCalculator.calculateCurrentStreak(
      dates,
      currentDate: DateTime(2024, 12, 31),
    );

    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(50));
    expect(streak, equals(365));
  });

  testWidgets('large task list should render smoothly', (tester) async {
    final largeTasks = List.generate(1000, (index) => Task(
      id: 'task_$index',
      templateId: 'template_1',
      title: 'Task $index',
      status: TaskStatus.pending,
      date: '2024-01-01',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskListView(tasks: largeTasks),
        ),
      ),
    );

    // Scroll through list to test performance
    await tester.fling(find.byType(ListView), Offset(0, -1000), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(TaskTile), findsWidgets);
  });
});
```

### Load Testing

```bash
# Load test the API using Artillery
# artillery.yml
config:
  target: 'http://localhost:8080'
  phases:
    - duration: 60
      arrivalRate: 10
  defaults:
    headers:
      Authorization: 'Bearer {{ token }}'

scenarios:
  - name: "Get user tasks"
    weight: 60
    flow:
      - post:
          url: "/api/v1/auth/login"
          json:
            email: "test@example.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "token"
      - get:
          url: "/api/v1/users/{{ userId }}/tasks?startDate=2024-01-01&endDate=2024-01-31"

  - name: "Update task status"
    weight: 30
    flow:
      - put:
          url: "/api/v1/users/{{ userId }}/tasks/{{ taskId }}"
          json:
            status: "completed"
            completedAt: "{{ $timestamp }}"

  - name: "Sync changes"
    weight: 10
    flow:
      - post:
          url: "/api/v1/sync/{{ userId }}/upload"
          json:
            changes: []
```

### Test Data Management

```dart
// Test data factories for consistent test setup
class TestDataFactory {
  static User createUser({
    String? id,
    String? email,
    String? name,
  }) {
    return User(
      id: id ?? 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email ?? 'test@example.com',
      name: name ?? 'Test User',
      createdAt: DateTime.now(),
      preferences: UserPreferences(
        timezone: 'UTC',
        theme: 'light',
        notifications: true,
      ),
      gamification: UserGamification(
        level: 1,
        totalXP: 0,
        todayXP: 0,
        tomorrowXP: 0,
        coins: 0,
        diamonds: 0,
      ),
    );
  }

  static TaskTemplate createTaskTemplate({
    String? id,
    String? userId,
    String? title,
  }) {
    return TaskTemplate(
      id: id ?? 'template_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'test_user',
      title: title ?? 'Test Task',
      description: 'Test description',
      category: 'test',
      difficulty: 1,
      recurrencyType: RecurrencyType.daily,
      recurrencyConfig: RecurrencyConfig(
        daysOfWeek: [1, 2, 3, 4, 5],
        times: ['08:00'],
      ),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Task createTask({
    String? id,
    String? templateId,
    String? userId,
    TaskStatus? status,
    String? date,
  }) {
    return Task(
      id: id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      templateId: templateId ?? 'template_1',
      userId: userId ?? 'test_user',
      date: date ?? '2024-01-01',
      status: status ?? TaskStatus.pending,
      completedAt: status == TaskStatus.completed ? DateTime.now() : null,
      xpEarned: status == TaskStatus.completed ? 20 : 0,
      coinsEarned: status == TaskStatus.completed ? 10 : 0,
      notes: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

// Database setup for integration tests
class TestDatabaseSetup {
  static Future<void> setupTestDatabase() async {
    await DatabasePool.initialize();

    // Create test schema
    await DatabasePool.withConnection((conn) async {
      await conn.execute('''
        CREATE SCHEMA IF NOT EXISTS test;
        SET search_path TO test;
      ''');

      // Run migrations for test schema
      final initSql = await File('scripts/init.sql').readAsString();
      await conn.execute(initSql);
    });
  }

  static Future<void> cleanupTestDatabase() async {
    await DatabasePool.withConnection((conn) async {
      await conn.execute('DROP SCHEMA IF EXISTS test CASCADE;');
    });
  }

  static Future<void> seedTestData() async {
    final user = TestDataFactory.createUser();
    final template = TestDataFactory.createTaskTemplate(userId: user.id);
    final task = TestDataFactory.createTask(
      templateId: template.id,
      userId: user.id,
    );

    // Insert test data
    await UserRepository.create(user);
    await TaskTemplateRepository.create(template);
    await TaskRepository.create(task);
  }
}
```

## 📊 Code Quality Metrics

### Coverage Requirements

```yaml
# test/analysis_options.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"

linter:
  rules:
    - always_declare_return_types
    - avoid_empty_else
    - prefer_const_constructors
    - use_super_parameters

# Coverage configuration
test:
  coverage:
    minimum: 80  # Minimum 80% test coverage
    exclude:
      - "**/*.g.dart"
      - "**/*.freezed.dart"
      - "**/main.dart"
```

### Static Analysis

```bash
# Automated code quality checks
#!/bin/bash

# Dart analysis
echo "Running Dart analysis..."
dart analyze --fatal-infos

# Flutter analysis
echo "Running Flutter analysis..."
cd client
flutter analyze --fatal-infos

# Check formatting
echo "Checking code formatting..."
dart format --set-exit-if-changed .

# Run tests with coverage
echo "Running tests with coverage..."
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Check coverage threshold
coverage_percent=$(lcov --summary coverage/lcov.info | grep -o '[0-9.]\+%' | head -1 | sed 's/%//')
if (( $(echo "$coverage_percent < 80" | bc -l) )); then
    echo "Coverage $coverage_percent% is below 80% threshold"
    exit 1
fi

echo "All quality checks passed!"
```

---

## 📚 Additional Resources

- **Performance Monitoring**: See `server/lib/middleware/performance_middleware.dart`
- **Security Middleware**: See `server/lib/middleware/security_middleware.dart`
- **Test Utilities**: See `test/utils/` directory
- **Load Testing Scripts**: See `scripts/load_tests/`

---

*This document is part of the Apogee technical documentation. For questions or clarifications, please refer to the [Contributing Guide](../CONTRIBUTING.md).*