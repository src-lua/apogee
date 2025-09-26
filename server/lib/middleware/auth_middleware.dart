import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../services/auth_service.dart';

/// Auth data container for context
class AuthData {
  final String userId;
  final String deviceId;

  const AuthData({required this.userId, required this.deviceId});
}

/// Authentication middleware for protected routes
/// Validates JWT tokens and provides user context
Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final request = context.request;

      // Skip authentication for OPTIONS requests (CORS preflight)
      if (request.method == HttpMethod.options) {
        return handler(context);
      }

      // Extract token from Authorization header
      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.json(
          statusCode: 401,
          body: {
            'error': 'Authentication required',
            'message': 'Missing or invalid Authorization header',
          },
        );
      }

      final token = authHeader.substring(7); // Remove 'Bearer ' prefix

      try {
        // Validate JWT token
        final payload = AuthService.validateToken(token);
        final userId = payload['userId'] as String;
        final deviceId = payload['deviceId'] as String;

        // Add auth data to request context for downstream handlers
        final authData = AuthData(userId: userId, deviceId: deviceId);
        final updatedContext = context.provide<AuthData>(() => authData);

        return handler(updatedContext);
      } catch (e) {
        return Response.json(
          statusCode: 401,
          body: {
            'error': 'Invalid token',
            'message': e.toString(),
          },
        );
      }
    };
  };
}

/// Middleware specifically for user-related operations
/// Ensures the authenticated user can only access their own data
Middleware userOwnershipMiddleware() {
  return (handler) {
    return (context) async {
      final authData = context.read<AuthData>();
      final authenticatedUserId = authData.userId;
      final requestedUserId = context.request.uri.pathSegments
          .skip(2) // Skip 'api', 'v1'
          .firstWhere((segment) => segment.isNotEmpty, orElse: () => '');

      // Allow access if no specific user ID in path or if it matches authenticated user
      if (requestedUserId.isEmpty || requestedUserId == authenticatedUserId) {
        return handler(context);
      }

      return Response.json(
        statusCode: 403,
        body: {
          'error': 'Access denied',
          'message': 'You can only access your own data',
        },
      );
    };
  };
}