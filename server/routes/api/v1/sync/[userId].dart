import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/services/database_service.dart';
import '../../../../lib/middleware/auth_middleware.dart';

/// Handles data synchronization for offline-first architecture
/// GET /api/v1/sync/[userId] - Get changes since last sync
/// POST /api/v1/sync/[userId] - Upload local changes
Future<Response> onRequest(RequestContext context, String userId) async {
  return switch (context.request.method) {
    HttpMethod.get => await _handleGetChanges(context, userId),
    HttpMethod.post => await _handleUploadChanges(context, userId),
    HttpMethod.options => _handleOptions(),
    _ => Response(statusCode: HttpStatus.methodNotAllowed),
  };
}

/// Get all changes since the specified timestamp
/// Supports incremental sync for efficiency
Future<Response> _handleGetChanges(RequestContext context, String userId) async {
  try {
    final authData = context.read<AuthData>();
    final authenticatedUserId = authData.userId;

    // Ensure user can only sync their own data
    if (userId != authenticatedUserId) {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'Access denied',
          'message': 'You can only sync your own data',
        },
      );
    }

    // Get sync timestamp from query parameters
    final sinceParam = context.request.uri.queryParameters['since'];
    DateTime? since;

    if (sinceParam != null) {
      try {
        since = DateTime.parse(sinceParam);
      } catch (e) {
        return Response.json(
          statusCode: 400,
          body: {
            'error': 'Invalid timestamp',
            'message': 'The "since" parameter must be a valid ISO 8601 timestamp',
          },
        );
      }
    }

    // Default to 30 days ago if no timestamp provided
    since ??= DateTime.now().subtract(const Duration(days: 30));

    // Get all modified entities
    // TODO: Implement findModifiedSince method in DatabaseService
    final changes = <String, dynamic>{};

    // Get current server timestamp for client to use in next sync
    final serverTimestamp = DateTime.now();

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'changes': changes,
          'serverTimestamp': serverTimestamp.toIso8601String(),
          'syncedAt': serverTimestamp.toIso8601String(),
        },
        'message': 'Sync data retrieved successfully',
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {
        'error': 'Sync failed',
        'message': 'Failed to retrieve sync data: ${e.toString()}',
      },
    );
  }
}

/// Upload local changes to server
/// Handles conflict resolution and data validation
Future<Response> _handleUploadChanges(RequestContext context, String userId) async {
  try {
    final authData = context.read<AuthData>();
    final authenticatedUserId = authData.userId;
    final deviceId = authData.deviceId;

    // Ensure user can only sync their own data
    if (userId != authenticatedUserId) {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'Access denied',
          'message': 'You can only sync your own data',
        },
      );
    }

    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final changes = data['changes'] as Map<String, dynamic>?;
    final clientTimestamp = data['clientTimestamp'] as String?;

    if (changes == null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Missing changes',
          'message': 'Changes data is required',
        },
      );
    }

    final conflicts = <Map<String, dynamic>>[];
    final applied = <Map<String, dynamic>>[];

    // Process user changes
    if (changes.containsKey('user')) {
      final result = await _processUserChanges(
        changes['user'] as Map<String, dynamic>,
        userId,
        deviceId,
      );
      if (result['conflict'] != null) {
        conflicts.add(result['conflict'] as Map<String, dynamic>);
      } else {
        applied.add({'type': 'user', 'id': userId});
      }
    }

    // Process task template changes
    if (changes.containsKey('taskTemplates')) {
      final templateChanges = changes['taskTemplates'] as List<dynamic>;
      for (final templateData in templateChanges) {
        final result = await _processTaskTemplateChanges(
          templateData as Map<String, dynamic>,
          userId,
          deviceId,
        );
        if (result['conflict'] != null) {
          conflicts.add(result['conflict'] as Map<String, dynamic>);
        } else {
          applied.add({'type': 'taskTemplate', 'id': result['id']});
        }
      }
    }

    // Process task changes
    if (changes.containsKey('tasks')) {
      final taskChanges = changes['tasks'] as List<dynamic>;
      for (final taskData in taskChanges) {
        final result = await _processTaskChanges(
          taskData as Map<String, dynamic>,
          userId,
          deviceId,
        );
        if (result['conflict'] != null) {
          conflicts.add(result['conflict'] as Map<String, dynamic>);
        } else {
          applied.add({'type': 'task', 'id': result['id']});
        }
      }
    }

    final serverTimestamp = DateTime.now();

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'appliedChanges': applied,
          'conflicts': conflicts,
          'serverTimestamp': serverTimestamp.toIso8601String(),
        },
        'message': conflicts.isEmpty
            ? 'All changes applied successfully'
            : 'Some changes had conflicts that need resolution',
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {
        'error': 'Sync failed',
        'message': 'Failed to upload changes: ${e.toString()}',
      },
    );
  }
}

/// Process user data changes with conflict detection
Future<Map<String, dynamic>> _processUserChanges(
  Map<String, dynamic> userData,
  String userId,
  String deviceId,
) async {
  try {
    final serverUser = await DatabaseService.findUserById(userId);
    if (serverUser == null) {
      return {'error': 'User not found'};
    }

    final clientVersion = userData['syncVersion'] as int? ?? 0;

    // Check for conflicts
    if (clientVersion < serverUser.syncVersion) {
      return {
        'conflict': {
          'type': 'user',
          'id': userId,
          'clientVersion': clientVersion,
          'serverVersion': serverUser.syncVersion,
          'message': 'User data was modified on another device',
        }
      };
    }

    // Apply changes (server wins for most fields, but preserve client XP changes)
    final updatedUser = serverUser.copyWith(
      displayName: userData['displayName'] as String? ?? serverUser.displayName,
      // Preserve client's gamification progress
      baseXP: userData['baseXP'] as int? ?? serverUser.baseXP,
      todayXP: userData['todayXP'] as int? ?? serverUser.todayXP,
      tomorrowXP: userData['tomorrowXP'] as int? ?? serverUser.tomorrowXP,
      coins: userData['coins'] as int? ?? serverUser.coins,
      diamonds: userData['diamonds'] as int? ?? serverUser.diamonds,
      level: userData['level'] as int? ?? serverUser.level,
      currentStreak: userData['currentStreak'] as int? ?? serverUser.currentStreak,
      maxStreak: userData['maxStreak'] as int? ?? serverUser.maxStreak,
      // Update sync metadata
      syncVersion: serverUser.syncVersion + 1,
      lastSyncAt: DateTime.now(),
      deviceId: deviceId,
    );

    await DatabaseService.updateUser(updatedUser);
    return {'success': true};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Process task template changes
Future<Map<String, dynamic>> _processTaskTemplateChanges(
  Map<String, dynamic> templateData,
  String userId,
  String deviceId,
) async {
  // Implementation similar to user changes but for task templates
  // This would handle template creation, updates, and deletions
  return {'success': true, 'id': templateData['id']};
}

/// Process task changes
Future<Map<String, dynamic>> _processTaskChanges(
  Map<String, dynamic> taskData,
  String userId,
  String deviceId,
) async {
  // Implementation for task changes
  // Handles task status updates, completions, etc.
  return {'success': true, 'id': taskData['id']};
}

/// Handle CORS preflight requests
Response _handleOptions() {
  return Response(
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  );
}