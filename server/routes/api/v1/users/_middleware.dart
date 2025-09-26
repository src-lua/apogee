import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/middleware/auth_middleware.dart';

/// User routes middleware
/// Ensures authentication for all user-related operations
Handler middleware(Handler handler) {
  return handler
      .use(authMiddleware())
      .use(userOwnershipMiddleware());
}