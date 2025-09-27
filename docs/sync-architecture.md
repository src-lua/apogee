# Sync Architecture Documentation

Apogee implements an offline-first synchronization system that ensures data consistency between the Flutter client (Hive local storage) and the Dart Frog server (PostgreSQL database).

## 🎯 Design Principles

### Offline-First Strategy

1. **Local Storage Primary**: Hive database provides immediate responsiveness
2. **Server as Source of Truth**: Final authority for conflict resolution
3. **Graceful Degradation**: Full functionality without network connection
4. **Background Synchronization**: Non-blocking sync operations
5. **Conflict Resolution**: Intelligent merging with minimal data loss

### Key Benefits

- **Instant Responsiveness**: No network delays for local operations
- **Data Resilience**: Works without internet connection
- **Consistency Guarantees**: Eventually consistent with conflict resolution
- **Scalability**: Reduces server load through local-first operations

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter UI    │    │   Sync Service  │    │   Server API    │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Widgets   │ │    │ │   Manager   │ │    │ │  Endpoints  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│        │        │    │        │        │    │        │        │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │  Providers  │ │◄─▶ │ │ Conflict    │ │◄─▶ │ │   Routes    │ │
│ │             │ │    │ │ Resolution  │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│        │        │    │        │        │    │        │        │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │    Hive     │ │    │ │   Delta     │ │    │ │ PostgreSQL  │ │
│ │  Database   │ │    │ │   Tracker   │ │    │ │  Database   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📦 Data Models

### SyncData Structure

```dart
@HiveType(typeId: 4)
class SyncData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime lastModified;

  @HiveField(2)
  final DateTime? lastSynced;

  @HiveField(3)
  final SyncStatus status;

  @HiveField(4)
  final Map<String, dynamic> metadata;

  @HiveField(5)
  final int version;

  // Conflict resolution data
  @HiveField(6)
  final String? conflictResolution;

  @HiveField(7)
  final List<String> pendingChanges;
}

enum SyncStatus {
  synced,      // Up to date with server
  pending,     // Waiting to be uploaded
  conflict,    // Needs conflict resolution
  error,       // Sync failed
  deleted      // Marked for deletion
}
```

### Change Tracking

```dart
class ChangeTracker {
  // Track what changed for efficient delta sync
  final String entityId;
  final String entityType; // 'user', 'task', 'template'
  final ChangeType type;   // 'create', 'update', 'delete'
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final DateTime timestamp;
  final String userId;
}
```

## 🔄 Sync Flow

### 1. Client-to-Server Upload

```dart
class SyncUploadFlow {
  Future<SyncResult> uploadChanges() async {
    // 1. Gather pending changes
    final pendingChanges = await _gatherPendingChanges();

    // 2. Create sync package
    final syncPackage = SyncPackage(
      userId: currentUser.id,
      changes: pendingChanges,
      clientTimestamp: DateTime.now(),
      lastSyncTimestamp: await _getLastSyncTimestamp(),
    );

    // 3. Upload to server
    final response = await syncApi.uploadChanges(syncPackage);

    // 4. Handle response
    return _processSyncResponse(response);
  }

  Future<List<Change>> _gatherPendingChanges() async {
    final changes = <Change>[];

    // Check each entity type for pending changes
    changes.addAll(await _getPendingUserChanges());
    changes.addAll(await _getPendingTaskTemplateChanges());
    changes.addAll(await _getPendingTaskChanges());

    return changes;
  }
}
```

### 2. Server-to-Client Download

```dart
class SyncDownloadFlow {
  Future<SyncResult> downloadChanges() async {
    // 1. Request changes since last sync
    final lastSync = await _getLastSyncTimestamp();
    final response = await syncApi.getChangesSince(
      userId: currentUser.id,
      since: lastSync,
    );

    // 2. Apply changes with conflict detection
    for (final change in response.changes) {
      await _applyChangeWithConflictDetection(change);
    }

    // 3. Update sync metadata
    await _updateSyncTimestamp(response.serverTimestamp);

    return SyncResult.success();
  }

  Future<void> _applyChangeWithConflictDetection(Change change) async {
    final localEntity = await _getLocalEntity(change.entityId);

    if (localEntity == null) {
      // No local version, safe to apply
      await _applyChange(change);
      return;
    }

    final hasLocalChanges = await _hasUnSyncedChanges(change.entityId);
    if (!hasLocalChanges) {
      // No local changes, safe to apply server change
      await _applyChange(change);
      return;
    }

    // Conflict detected, use resolution strategy
    await _resolveConflict(localEntity, change);
  }
}
```

## ⚔️ Conflict Resolution

### Resolution Strategies

1. **Server Wins**: Server data always takes precedence
2. **Client Wins**: Local changes are preserved
3. **Merge**: Intelligent field-level merging
4. **User Decision**: Present conflict to user for resolution

### Implementation

```dart
class ConflictResolver {
  Future<Resolution> resolveConflict(
    LocalEntity localEntity,
    ServerChange serverChange,
  ) async {
    // Default strategy: Server wins with intelligent merging
    switch (serverChange.entityType) {
      case 'user':
        return _resolveUserConflict(localEntity, serverChange);
      case 'task':
        return _resolveTaskConflict(localEntity, serverChange);
      case 'taskTemplate':
        return _resolveTemplateConflict(localEntity, serverChange);
      default:
        return Resolution.serverWins(serverChange);
    }
  }

  Future<Resolution> _resolveTaskConflict(
    Task localTask,
    ServerChange serverChange,
  ) async {
    final serverTask = Task.fromJson(serverChange.data);

    // Special handling for task status changes
    if (localTask.status != serverTask.status) {
      // Completed tasks on client should generally win
      if (localTask.status == TaskStatus.completed) {
        return Resolution.clientWins(localTask);
      }

      // Server deletions win over local changes
      if (serverTask.status == TaskStatus.deleted) {
        return Resolution.serverWins(serverChange);
      }
    }

    // Merge other fields intelligently
    final mergedTask = Task(
      id: localTask.id,
      templateId: localTask.templateId,
      date: localTask.date,
      status: _mergeTaskStatus(localTask.status, serverTask.status),
      completedAt: localTask.completedAt ?? serverTask.completedAt,
      notes: localTask.notes.isNotEmpty ? localTask.notes : serverTask.notes,
      xpEarned: math.max(localTask.xpEarned, serverTask.xpEarned),
    );

    return Resolution.merged(mergedTask);
  }
}
```

## 📡 API Endpoints

### Sync Upload Endpoint

```dart
// POST /api/v1/sync/{userId}/upload
@Route.post('/sync/<userId>/upload')
Future<Response> uploadChanges(
  RequestContext context,
  String userId,
) async {
  final body = await context.request.json();
  final syncPackage = SyncPackage.fromJson(body);

  // Validate user authorization
  await _validateUserAccess(context, userId);

  // Process each change
  final results = <ChangeResult>[];
  for (final change in syncPackage.changes) {
    final result = await _processChange(userId, change);
    results.add(result);
  }

  // Return results with any conflicts
  return Response.json({
    'success': true,
    'serverTimestamp': DateTime.now().toIso8601String(),
    'results': results.map((r) => r.toJson()).toList(),
    'conflicts': results.where((r) => r.hasConflict).toList(),
  });
}
```

### Sync Download Endpoint

```dart
// GET /api/v1/sync/{userId}/changes?since=timestamp
@Route.get('/sync/<userId>/changes')
Future<Response> getChanges(
  RequestContext context,
  String userId,
) async {
  final sinceParam = context.request.uri.queryParameters['since'];
  final since = sinceParam != null ? DateTime.parse(sinceParam) : null;

  await _validateUserAccess(context, userId);

  // Get changes since timestamp
  final changes = await syncService.getChangesSince(userId, since);

  return Response.json({
    'success': true,
    'serverTimestamp': DateTime.now().toIso8601String(),
    'changes': changes.map((c) => c.toJson()).toList(),
    'hasMore': false, // Pagination support
  });
}
```

## 🔧 Implementation Details

### Hive Storage Structure

```dart
// Box organization for sync efficiency
class HiveBoxes {
  static const String users = 'users';
  static const String taskTemplates = 'task_templates';
  static const String tasks = 'tasks';
  static const String syncMetadata = 'sync_metadata';
  static const String pendingChanges = 'pending_changes';

  // Specialized boxes for performance
  static const String tasksToday = 'tasks_today';    // Fast access
  static const String streaks = 'streaks';           // Cached streaks
  static const String xpData = 'xp_data';           // XP calculations
}

// Efficient key structure
class HiveKeys {
  // User data: 'user_{userId}'
  static String user(String userId) => 'user_$userId';

  // Task templates: 'template_{templateId}'
  static String template(String templateId) => 'template_$templateId';

  // Daily tasks: 'task_{templateId}_{dayIsoString}'
  static String task(String templateId, String dayIso) => 'task_${templateId}_$dayIso';

  // Sync metadata: 'sync_{entityType}_{entityId}'
  static String sync(String entityType, String entityId) => 'sync_${entityType}_$entityId';
}
```

### Performance Optimizations

```dart
class SyncOptimizations {
  // Delta tracking to avoid full entity comparisons
  static final _changeTracker = ChangeTracker();

  // Batch operations for efficiency
  Future<void> batchSync() async {
    const batchSize = 50;
    final pendingChanges = await _getAllPendingChanges();

    for (int i = 0; i < pendingChanges.length; i += batchSize) {
      final batch = pendingChanges.skip(i).take(batchSize).toList();
      await _syncBatch(batch);
    }
  }

  // Smart scheduling to avoid blocking UI
  void scheduleBackgroundSync() {
    Timer.periodic(Duration(minutes: 5), (timer) async {
      if (await _isAppInBackground() && await _hasNetworkConnection()) {
        await _performBackgroundSync();
      }
    });
  }

  // Prioritized sync based on data importance
  Future<void> prioritizedSync() async {
    // 1. Critical user changes first
    await _syncCriticalUserData();

    // 2. Task completions second
    await _syncTaskCompletions();

    // 3. Template changes third
    await _syncTaskTemplates();

    // 4. Metadata and logs last
    await _syncMetadata();
  }
}
```

## 🚨 Error Handling

### Network Failures

```dart
class SyncErrorHandler {
  Future<SyncResult> handleSyncError(SyncError error) async {
    switch (error.type) {
      case SyncErrorType.networkTimeout:
        return _retryWithBackoff(error.operation);

      case SyncErrorType.serverError:
        if (error.isRetryable) {
          return _scheduleRetry(error.operation);
        }
        return _markAsFailed(error.operation);

      case SyncErrorType.authenticationError:
        await _refreshAuthentication();
        return _retryOperation(error.operation);

      case SyncErrorType.conflictError:
        return _handleConflictResolution(error.conflict);

      case SyncErrorType.dataCorruption:
        return _performDataRecovery(error.entityId);

      default:
        return SyncResult.failure(error);
    }
  }

  Future<SyncResult> _retryWithBackoff(SyncOperation operation) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation.execute();
      } catch (e) {
        if (attempt == maxRetries) rethrow;

        final delay = baseDelay * math.pow(2, attempt - 1);
        await Future.delayed(delay);
      }
    }

    return SyncResult.failure(SyncError.maxRetriesExceeded());
  }
}
```

### Data Integrity Checks

```dart
class IntegrityChecker {
  Future<bool> validateSyncIntegrity() async {
    // Check for orphaned records
    final orphanedTasks = await _findOrphanedTasks();
    if (orphanedTasks.isNotEmpty) {
      await _cleanupOrphanedTasks(orphanedTasks);
    }

    // Validate XP calculations
    final xpInconsistencies = await _validateXPConsistency();
    if (xpInconsistencies.isNotEmpty) {
      await _fixXPInconsistencies(xpInconsistencies);
    }

    // Check sync metadata consistency
    final metadataIssues = await _validateSyncMetadata();
    if (metadataIssues.isNotEmpty) {
      await _repairSyncMetadata(metadataIssues);
    }

    return true;
  }

  Future<List<Task>> _findOrphanedTasks() async {
    final allTasks = await taskService.getAllTasks();
    final allTemplates = await templateService.getAllTemplates();
    final templateIds = allTemplates.map((t) => t.id).toSet();

    return allTasks.where((task) => !templateIds.contains(task.templateId)).toList();
  }
}
```

## 📊 Monitoring & Analytics

### Sync Metrics

```dart
class SyncMetrics {
  // Track sync performance
  static final _syncDurations = <Duration>[];
  static final _conflictCounts = <String, int>{};
  static final _errorCounts = <SyncErrorType, int>{};

  static void recordSyncDuration(Duration duration) {
    _syncDurations.add(duration);
    _cleanupOldMetrics();
  }

  static void recordConflict(String entityType) {
    _conflictCounts[entityType] = (_conflictCounts[entityType] ?? 0) + 1;
  }

  static SyncHealthReport getHealthReport() {
    return SyncHealthReport(
      averageSyncDuration: _calculateAverageDuration(),
      conflictRate: _calculateConflictRate(),
      errorRate: _calculateErrorRate(),
      lastSuccessfulSync: _getLastSuccessfulSync(),
    );
  }
}
```

### Debug Tools

```dart
class SyncDebugger {
  // Visualize sync state for debugging
  Future<Map<String, dynamic>> getSyncDebugInfo() async {
    return {
      'pendingChanges': await _getPendingChangesCount(),
      'lastSyncTimes': await _getLastSyncTimes(),
      'conflictingEntities': await _getConflictingEntities(),
      'syncHealth': SyncMetrics.getHealthReport().toJson(),
      'storageStats': await _getStorageStats(),
    };
  }

  // Force full resync (for emergency recovery)
  Future<void> forceFullResync() async {
    await _clearSyncMetadata();
    await _markAllEntitiesAsPending();
    await _performFullSync();
  }
}
```

## 🧪 Testing Strategies

### Unit Tests

```dart
group('Sync Conflict Resolution', () {
  test('should prefer completed tasks over pending', () async {
    final localTask = Task(status: TaskStatus.completed);
    final serverChange = ServerChange(
      data: Task(status: TaskStatus.pending).toJson(),
    );

    final resolution = await conflictResolver.resolveConflict(
      localTask,
      serverChange,
    );

    expect(resolution.type, equals(ResolutionType.clientWins));
  });

  test('should handle network timeout gracefully', () async {
    when(mockSyncApi.uploadChanges(any)).thenThrow(TimeoutException(''));

    final result = await syncService.uploadChanges();

    expect(result.success, isFalse);
    expect(result.shouldRetry, isTrue);
  });
});
```

### Integration Tests

```dart
group('End-to-End Sync', () {
  testWidgets('should sync task completion between devices', (tester) async {
    // Simulate task completion on device A
    await deviceA.completeTask(taskId);
    await deviceA.sync();

    // Sync on device B
    await deviceB.sync();

    // Verify task is completed on device B
    final taskOnB = await deviceB.getTask(taskId);
    expect(taskOnB.status, equals(TaskStatus.completed));
  });
});
```

## 🚀 Future Enhancements

### Planned Improvements

1. **Real-time Sync**: WebSocket-based real-time updates
2. **Conflict Visualization**: UI for manual conflict resolution
3. **Selective Sync**: Allow users to choose what data to sync
4. **Compression**: Compress sync payloads for bandwidth efficiency
5. **Peer-to-Peer**: Direct device-to-device sync for local networks

### Performance Roadmap

1. **Incremental Sync**: More granular change tracking
2. **Intelligent Batching**: Dynamic batch sizes based on network conditions
3. **Predictive Sync**: Anticipate sync needs based on user patterns
4. **Background Processing**: Utilize background isolates for sync operations

---

## 📚 Additional Resources

- **Implementation**: See `client/lib/services/sync_service.dart`
- **Server Endpoints**: See `server/routes/sync/`
- **Models**: See `shared/models/lib/sync_data.dart`
- **API Documentation**: See [API Documentation](api.md)

---

*This document is part of the Apogee technical documentation. For questions or clarifications, please refer to the [Contributing Guide](../CONTRIBUTING.md).*