import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../../../../lib/services/database_service.dart';
import '../../../../../lib/middleware/auth_middleware.dart';

/// Handles user profile operations
/// GET /api/v1/users/[userId] - Get user profile
/// PUT /api/v1/users/[userId] - Update user profile
Future<Response> onRequest(RequestContext context, String userId) async {
  return switch (context.request.method) {
    HttpMethod.get => await _handleGetUser(context, userId),
    HttpMethod.put => await _handleUpdateUser(context, userId),
    HttpMethod.options => _handleOptions(),
    _ => Response(statusCode: HttpStatus.methodNotAllowed),
  };
}

/// Get user profile data
Future<Response> _handleGetUser(RequestContext context, String userId) async {
  try {
    final authData = context.read<AuthData>();
    final authenticatedUserId = authData.userId;

    // Ensure user can only access their own data
    if (userId != authenticatedUserId) {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'Access denied',
          'message': 'You can only access your own profile',
        },
      );
    }

    final user = await DatabaseService.findUserById(userId);
    if (user == null) {
      return Response.json(
        statusCode: 404,
        body: {
          'error': 'User not found',
          'message': 'The requested user does not exist',
        },
      );
    }

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'data': user.toJson(),
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {
        'error': 'Internal server error',
        'message': 'Failed to retrieve user profile',
      },
    );
  }
}

/// Update user profile data
Future<Response> _handleUpdateUser(RequestContext context, String userId) async {
  try {
    final authData = context.read<AuthData>();
    final authenticatedUserId = authData.userId;
    final deviceId = authData.deviceId;

    // Ensure user can only update their own data
    if (userId != authenticatedUserId) {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'Access denied',
          'message': 'You can only update your own profile',
        },
      );
    }

    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Get current user data
    final currentUser = await DatabaseService.findUserById(userId);
    if (currentUser == null) {
      return Response.json(
        statusCode: 404,
        body: {
          'error': 'User not found',
          'message': 'The user to update does not exist',
        },
      );
    }

    // Update allowed fields only
    final updatedUser = currentUser.copyWith(
      displayName: data['displayName'] as String? ?? currentUser.displayName,
      // Only update gamification data if provided and valid
      baseXP: _validateAndGet<int>(data, 'baseXP', currentUser.baseXP),
      todayXP: _validateAndGet<int>(data, 'todayXP', currentUser.todayXP),
      tomorrowXP: _validateAndGet<int>(data, 'tomorrowXP', currentUser.tomorrowXP),
      coins: _validateAndGet<int>(data, 'coins', currentUser.coins),
      diamonds: _validateAndGet<int>(data, 'diamonds', currentUser.diamonds),
      level: _validateAndGet<int>(data, 'level', currentUser.level),
      currentStreak: _validateAndGet<int>(data, 'currentStreak', currentUser.currentStreak),
      maxStreak: _validateAndGet<int>(data, 'maxStreak', currentUser.maxStreak),
      // Always update sync metadata
      deviceId: deviceId,
      syncVersion: currentUser.syncVersion + 1,
      lastSyncAt: DateTime.now(),
    );

    await DatabaseService.updateUser(updatedUser);

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'data': updatedUser.toJson(),
        'message': 'User profile updated successfully',
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {
        'error': 'Internal server error',
        'message': 'Failed to update user profile: ${e.toString()}',
      },
    );
  }
}

/// Helper function to safely extract and validate data
T _validateAndGet<T>(Map<String, dynamic> data, String key, T defaultValue) {
  final value = data[key];
  if (value is T) return value;
  return defaultValue;
}

/// Handle CORS preflight requests
Response _handleOptions() {
  return Response(
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  );
}