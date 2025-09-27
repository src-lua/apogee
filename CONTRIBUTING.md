# Contributing to Apogee

We welcome contributions to Apogee! This document provides guidelines for contributing to the project.

## 🚀 Quick Start for Contributors

### Development Environment Setup

1. **Prerequisites**
   - Flutter SDK 3.9.2+
   - Docker & Docker Compose
   - Git
   - Dart SDK (included with Flutter)

2. **Initial Setup**
   ```bash
   git clone <repository-url>
   cd apogee

   # Start database
   docker-compose up -d postgres

   # Setup server
   cd server
   dart pub get
   dart pub global activate dart_frog_cli

   # Setup client
   cd ../client
   flutter pub get
   flutter packages pub run build_runner build

   # Setup shared models
   cd ../shared/models
   dart pub get
   dart run build_runner build
   ```

## 🏗️ Development Workflow

### Branch Strategy
1. **Main Branch**: `main` - stable, deployable code
2. **Feature Branches**: `feature/feature-name` - new features
3. **Bug Fixes**: `fix/bug-description` - bug fixes
4. **Docs**: `docs/documentation-topic` - documentation updates

### Making Changes

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/awesome-feature
   ```

2. **Make Your Changes**
   - Follow the code organization guidelines below
   - Write tests for new functionality
   - Update documentation if needed

3. **Test Your Changes**
   ```bash
   # Client tests
   cd client && flutter test

   # Server tests
   cd server && dart test

   # Lint checks
   cd client && flutter analyze
   ```

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add awesome feature

   - Implement feature X
   - Add tests for feature X
   - Update documentation"
   ```

5. **Submit Pull Request**
   - Create PR with clear description
   - Link any related issues
   - Ensure CI passes
   - Request review from team members

## 📋 Code Organization

### Project Structure
- **Models**: Shared between client/server in `shared/models/`
- **Services**: Business logic layer
- **Clean Architecture**: Clear separation of concerns
- **English Comments**: All documentation and comments in English

### Shared Models Package
- All data models live in `shared/models/lib/`
- Use JSON serialization with `build_runner`
- Keep models synchronized between client and server
- Run `dart run build_runner build` after model changes

### Client Architecture (`client/`)
```
lib/
├── models/          # Client-specific models
├── services/        # Local services (Hive, sync)
├── pages/           # UI screens
├── widgets/         # Reusable components
├── providers/       # State management
└── utils/           # Helper functions
```

### Server Architecture (`server/`)
```
lib/
├── middleware/      # Auth, rate limiting, CORS
├── services/        # Database, auth, business logic
└── utils/           # Helper functions
routes/              # API endpoints
```

## 🧪 Testing Guidelines

### Test Coverage Requirements
- **Unit Tests**: All business logic (XP calculations, sync logic)
- **Integration Tests**: Server-client communication
- **Widget Tests**: Critical UI components
- **End-to-End Tests**: Full user journeys

### Writing Tests
```dart
// Example unit test
test('XP calculation should cap at 200 + 25% overflow', () {
  final xp = calculateTodayXP(rawXP: 300);
  expect(xp, equals(250)); // 200 + 50 (25% of 200)
});

// Example widget test
testWidgets('Task tile should show completion status', (tester) async {
  await tester.pumpWidget(TaskTile(task: completedTask));
  expect(find.byIcon(Icons.check_circle), findsOneWidget);
});
```

### Running Tests
```bash
# Run all client tests
cd client && flutter test

# Run specific test file
cd client && flutter test test/services/xp_service_test.dart

# Run with coverage
cd client && flutter test --coverage
```

## 🎯 Code Style

### Dart/Flutter Style
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` to check for issues
- Format code with `dart format`
- Use meaningful variable and function names

### Commit Message Format
```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```bash
feat(client): add XP progress visualization

- Implement circular progress indicator
- Add level-up animations
- Update XP service tests

fix(server): resolve authentication token validation

- Fix JWT token expiration handling
- Add proper error responses
- Update middleware tests
```

## 🔧 Database Migrations

### Creating Migrations
1. Add new migration to `scripts/migrations/`
2. Use semantic versioning: `001_initial_schema.sql`
3. Always include rollback scripts
4. Test migrations on development database

### Migration Example
```sql
-- 002_add_user_preferences.sql
ALTER TABLE users ADD COLUMN preferences JSONB DEFAULT '{}';
CREATE INDEX idx_users_preferences ON users USING gin(preferences);

-- Rollback: 002_add_user_preferences_rollback.sql
DROP INDEX IF EXISTS idx_users_preferences;
ALTER TABLE users DROP COLUMN IF EXISTS preferences;
```

## 🔒 Security Guidelines

### Authentication
- Use JWT tokens for API authentication
- Store tokens securely in Flutter Secure Storage
- Implement token refresh logic
- Never log sensitive information

### Input Validation
- Validate all inputs on both client and server
- Use parameterized queries for database operations
- Sanitize user input in UI components
- Follow OWASP security guidelines

### API Security
- Implement rate limiting
- Use HTTPS in production
- Validate request payloads
- Return consistent error responses

## 🚀 Performance Guidelines

### Client Performance
- Use `const` constructors where possible
- Implement lazy loading for large lists
- Optimize images and assets
- Use Flutter DevTools for profiling

### Server Performance
- Use connection pooling for database
- Implement caching where appropriate
- Monitor API response times
- Use database indexes effectively

### Database Performance
- Design efficient queries
- Use proper indexes
- Monitor query performance
- Implement data archiving for old records

## 📝 Documentation

### Code Documentation
- Document complex business logic
- Use meaningful comments for non-obvious code
- Keep documentation up to date with changes
- Include examples in documentation

### API Documentation
- Document all endpoints
- Include request/response examples
- Specify error codes and messages
- Keep OpenAPI specs updated

## 🐛 Bug Reports

### Reporting Issues
1. Check existing issues first
2. Use issue templates
3. Provide reproduction steps
4. Include environment details
5. Add relevant logs/screenshots

### Issue Labels
- `bug`: Something isn't working
- `enhancement`: New feature request
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `documentation`: Documentation improvements

## 💡 Feature Requests

### Proposing Features
1. Create GitHub issue with feature template
2. Describe the problem you're solving
3. Propose a solution
4. Consider implementation complexity
5. Discuss with maintainers before starting

## 🤝 Code Review

### Review Process
1. All changes require review
2. Address review feedback promptly
3. Be respectful in feedback
4. Focus on code quality and maintainability
5. Approve once satisfied with changes

### Review Checklist
- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No security vulnerabilities
- [ ] Performance considerations addressed
- [ ] Breaking changes are documented

## 📞 Getting Help

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and general discussion
- **Pull Requests**: Code review and collaboration

### Development Questions
- Check existing documentation first
- Search closed issues for similar problems
- Create discussion thread for complex questions
- Be specific about your environment and steps

---

## 📜 Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain a professional environment
- Report inappropriate behavior

---

Thank you for contributing to Apogee! 🚀