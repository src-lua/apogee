import 'package:dart_frog/dart_frog.dart';
import '../../lib/middleware/auth_middleware.dart';
import '../../lib/middleware/rate_limit_middleware.dart';

/// API-specific middleware layer
/// Handles authentication, rate limiting, and API versioning
Handler middleware(Handler handler) {
  return handler
      .use(rateLimitMiddleware(requestsPerMinute: 60))
      .use(apiVersionMiddleware());
}

/// API versioning middleware
/// Ensures consistent API versioning across all endpoints
Middleware apiVersionMiddleware() {
  return (handler) {
    return (context) async {
      final response = await handler(context);

      return response.copyWith(
        headers: {
          ...response.headers,
          'API-Version': 'v1',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
    };
  };
}