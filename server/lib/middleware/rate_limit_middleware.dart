import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

/// Rate limiting middleware to prevent API abuse
/// Tracks requests per IP address and enforces limits
Middleware rateLimitMiddleware({
  int requestsPerMinute = 60,
  int requestsPerHour = 1000,
}) {
  // In-memory store for request tracking
  // In production, this should use Redis or similar
  final Map<String, List<DateTime>> requestHistory = {};

  return (handler) {
    return (context) async {
      final request = context.request;
      final clientIP = _getClientIP(request);

      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      // Get or create request history for this IP
      final history = requestHistory.putIfAbsent(clientIP, () => <DateTime>[]);

      // Remove old entries
      history.removeWhere((timestamp) => timestamp.isBefore(oneHourAgo));

      // Count recent requests
      final recentMinuteRequests = history
          .where((timestamp) => timestamp.isAfter(oneMinuteAgo))
          .length;
      final recentHourRequests = history.length;

      // Check rate limits
      if (recentMinuteRequests >= requestsPerMinute) {
        return Response.json(
          statusCode: 429,
          body: {
            'error': 'Rate limit exceeded',
            'message': 'Too many requests per minute. Limit: $requestsPerMinute/min',
            'retryAfter': 60,
          },
          headers: {
            'Retry-After': '60',
            'X-RateLimit-Limit': requestsPerMinute.toString(),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': (now.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000).toString(),
          },
        );
      }

      if (recentHourRequests >= requestsPerHour) {
        return Response.json(
          statusCode: 429,
          body: {
            'error': 'Rate limit exceeded',
            'message': 'Too many requests per hour. Limit: $requestsPerHour/hour',
            'retryAfter': 3600,
          },
          headers: {
            'Retry-After': '3600',
            'X-RateLimit-Limit': requestsPerHour.toString(),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': (now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000).toString(),
          },
        );
      }

      // Record this request
      history.add(now);

      // Add rate limit headers to response
      final response = await handler(context);
      final remainingMinute = requestsPerMinute - recentMinuteRequests - 1;
      final remainingHour = requestsPerHour - recentHourRequests - 1;

      return response.copyWith(
        headers: {
          ...response.headers,
          'X-RateLimit-Limit-Minute': requestsPerMinute.toString(),
          'X-RateLimit-Remaining-Minute': remainingMinute.toString(),
          'X-RateLimit-Limit-Hour': requestsPerHour.toString(),
          'X-RateLimit-Remaining-Hour': remainingHour.toString(),
        },
      );
    };
  };
}

/// Extracts client IP address from request
/// Handles various proxy headers for accurate identification
String _getClientIP(Request request) {
  // Check for forwarded headers (common in production environments)
  final xForwardedFor = request.headers['X-Forwarded-For'];
  if (xForwardedFor != null && xForwardedFor.isNotEmpty) {
    // Take the first IP in the chain
    return xForwardedFor.split(',').first.trim();
  }

  final xRealIP = request.headers['X-Real-IP'];
  if (xRealIP != null && xRealIP.isNotEmpty) {
    return xRealIP.trim();
  }

  // Fallback to connection info
  return request.connectionInfo?.remoteAddress.address ?? 'unknown';
}