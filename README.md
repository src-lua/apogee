# Apogee - Professional Habit Tracker

A sophisticated habit tracking application with gamification features, built using Flutter and Dart with an offline-first architecture.

## ✨ Key Features

- **🎮 Advanced Gamification**: XP system, levels, coins, and diamonds with 2 AM deadline logic
- **📱 Cross-Platform**: Flutter app for iOS, Android, and Web
- **🔄 Offline-First Sync**: Works without internet, syncs when connected
- **⚡ Real-Time Updates**: Instant responsiveness with background synchronization
- **🏗️ Professional Architecture**: Clean separation, shared models, team-ready codebase

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK** 3.9.2+
- **Docker & Docker Compose**
- **Git**

### Development Setup

```bash
# 1. Clone repository
git clone <repository-url>
cd apogee

# 2. Start database
docker-compose up -d postgres

# 3. Start server (Terminal 1)
cd server
dart pub get
dart pub global activate dart_frog_cli
dart_frog dev  # Runs on http://localhost:8080

# 4. Start client (Terminal 2)
cd client
flutter pub get
flutter packages pub run build_runner build
flutter run -d chrome --web-port 3000  # Web development
# OR: flutter run  # Mobile/desktop
```

### Quick Commands

```bash
# Development
flutter analyze                    # Lint client code
flutter test                      # Run client tests
dart analyze                      # Lint server code
dart test                         # Run server tests

# Database
docker-compose up -d postgres     # Start PostgreSQL
docker-compose logs postgres      # View database logs
# pgAdmin: http://localhost:8081 (admin@apogee.dev / admin123)
```

## 📁 Project Structure

```
apogee/
├── 📱 client/           # Flutter app (offline-first UI)
├── 🖥️  server/           # Dart Frog API (authentication, sync)
├── 📦 shared/models/    # Shared data models (JSON serialization)
├── 🐳 docker-compose.yml # Local development environment
├── 📊 scripts/          # Database initialization
└── 📚 docs/             # Comprehensive documentation
```

## 🎯 Core Systems

### XP & Gamification
- **Daily XP Cap**: 200 XP + 25% overflow (250 max)
- **2 AM Deadline**: Tasks must be completed by 2 AM next day
- **Triple Currency**: XP (progression), Coins (rewards), Diamonds (levels)
- **Smart Gap Handling**: 0-2 AM period with intelligent date logic

### Offline-First Architecture
- **Local Storage**: Hive database for instant responsiveness
- **Background Sync**: Automatic server synchronization
- **Conflict Resolution**: Server authority with intelligent merging
- **Data Integrity**: Version tracking and validation

## 📚 Documentation

Detailed documentation is available in the `docs/` directory:

| Document | Description |
|----------|-------------|
| **[🎮 XP System](docs/xp-system.md)** | Complete XP mechanics, calculations, and gap period logic |
| **[🔄 Sync Architecture](docs/sync-architecture.md)** | Offline-first sync, conflict resolution, and data flow |
| **[📡 API Reference](docs/api.md)** | Complete REST API documentation with examples |
| **[🚀 Deployment Guide](docs/deployment.md)** | Production deployment, Docker, cloud platforms |
| **[⚡ Development Guide](docs/development.md)** | Performance, security, testing, and code quality |
| **[🤝 Contributing Guide](CONTRIBUTING.md)** | Team workflow, code standards, and contribution process |

## 🧪 Testing

```bash
# Client tests
cd client && flutter test --coverage

# Server tests
cd server && dart test

# Integration tests
flutter test integration_test/

# Load testing
arctillery run artillery.yml
```

## 🚀 Deployment

### Quick Deploy (Docker)
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### Platform-Specific
- **Docker**: Complete containerized deployment
- **Google Cloud Run**: Serverless API deployment
- **AWS ECS**: Container orchestration
- **Flutter Web**: Static hosting (Firebase, Netlify, S3)
- **Mobile Apps**: Play Store / App Store distribution

See [Deployment Guide](docs/deployment.md) for detailed instructions.

## 🔧 Development Tools

- **Health Check**: `curl http://localhost:8080/health`
- **Database Admin**: http://localhost:8081 (pgAdmin)
- **API Documentation**: http://localhost:8080/api/docs
- **Flutter DevTools**: Built-in debugging and profiling

## 🎯 Roadmap

Current development priorities are tracked in [TODO.md](TODO.md):

1. **Server-Client Integration** (High Priority)
2. **Authentication System**
3. **Data Synchronization**
4. **Advanced Features** (Coin store, social features)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for:
- Development environment setup
- Code standards and style guidelines
- Testing requirements
- Pull request process

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Built with ❤️ using Dart & Flutter** | [Issues](https://github.com/your-org/apogee/issues) | [Discussions](https://github.com/your-org/apogee/discussions)