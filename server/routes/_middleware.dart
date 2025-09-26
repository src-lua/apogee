import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

/// Global middleware for all routes
/// Handles CORS, logging, and common security headers
Handler middleware(Handler handler) {
  return handler
      .use(corsHeaders())
      .use(requestLogger())
      .use(securityHeaders());
}

/// CORS configuration for client-server communication
Middleware corsHeaders() {
  return (handler) {
    return (context) async {
      if (context.request.method == 'OPTIONS') {
        return Response.json(
          statusCode: 200,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
            'Access-Control-Max-Age': '86400',
          },
        );
      }

      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        },
      );
    };
  };
}

/// Request logging middleware for debugging and monitoring
Middleware requestLogger() {
  return (handler) {
    return (context) async {
      final stopwatch = Stopwatch()..start();
      final request = context.request;

      print('[${DateTime.now().toIso8601String()}] '
            '${request.method} ${request.uri}');

      final response = await handler(context);

      stopwatch.stop();
      print('[${DateTime.now().toIso8601String()}] '
            '${request.method} ${request.uri} - '
            '${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)');

      return response;
    };
  };
}

/// Security headers middleware
Middleware securityHeaders() {
  return (handler) {
    return (context) async {
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'X-XSS-Protection': '1; mode=block',
          'Referrer-Policy': 'strict-origin-when-cross-origin',
        },
      );
    };
  };
}