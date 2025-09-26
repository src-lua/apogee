# Apogee - Habit Tracker with Gamification

A sophisticated habit tracking application built with Flutter and Dart, featuring client-server synchronization, advanced XP mechanics, and professional team development architecture.

## 🏗️ Architecture Overview

### **Pure Dart Stack**
- **Client**: Flutter with offline-first capabilities
- **Server**: Dart Frog API with PostgreSQL
- **Shared**: Common models and utilities
- **Database**: PostgreSQL with JSONB support

### **Key Features**
- **Triple Currency System**: XP (progression), Coins (rewards), Diamonds (level rewards)
- **Complex XP Logic**: 2 AM deadline with gap period handling
- **Offline-First Sync**: Conflict resolution and data integrity
- **Professional Architecture**: Clean separation for team development

## 🚀 Quick Start

### **Prerequisites**
- Flutter SDK 3.9.2+
- Docker & Docker Compose
- Git

### **Development Setup**

1. **Clone and Setup**
```bash
git clone <repository-url>
cd apogee
```

2. **Start Database & Server**
```bash
docker-compose up -d postgres                 # Start PostgreSQL
cd server
dart pub get                                  # Install server dependencies
dart pub global activate dart_frog_cli        # Install Dart Frog CLI (one-time)

# Start server (use one of these options):
dart_frog dev                                 # If dart_frog is in PATH
# OR (Windows with full path):
# C:/Users/[USERNAME]/AppData/Local/Pub/Cache/bin/dart_frog.bat dev
```

3. **Run Flutter Client**
```bash
cd client
flutter pub get
flutter packages pub run build_runner build  # Generate Hive adapters
flutter run
```

### **⚠️ Current Status**
- **Database**: PostgreSQL runs successfully with Docker
- **Server**: Basic health endpoint working at http://localhost:8080
- **Client**: Flutter app runs with existing local-first functionality
- **Sync**: Server-client integration requires additional setup (see Development Notes)

## 📁 Repository Structure

```
apogee/
├── client/                  # Flutter mobile app
│   ├── lib/
│   │   ├── models/          # Client-specific models
│   │   ├── services/        # Local services (Hive, sync)
│   │   ├── pages/           # UI screens
│   │   └── widgets/         # Reusable components
│   └── pubspec.yaml
│
├── server/                  # Dart Frog API server
│   ├── lib/
│   │   ├── middleware/      # Auth, rate limiting
│   │   └── services/        # Database, auth services
│   ├── routes/              # API endpoints
│   └── pubspec.yaml
│
├── shared/                  # Common code
│   └── models/              # Shared data models
│       ├── lib/
│       │   ├── enums/       # TaskStatus, RecurrencyType
│       │   ├── task.dart    # Task entity
│       │   ├── user.dart    # User entity
│       │   └── sync_data.dart
│       └── pubspec.yaml
│
├── scripts/                 # Database and deployment
│   └── init.sql             # PostgreSQL schema
├── docker-compose.yml       # Local development
└── README.md
```

## 🔧 Development Commands

### **Server Commands**
```bash
cd server
dart pub get                 # Install dependencies
dart run                     # Development server
dart compile exe main.dart   # Build production binary
```

### **Client Commands**
```bash
cd client
flutter pub get                                    # Install dependencies
flutter packages pub run build_runner build        # Generate Hive adapters
flutter run                                        # Development mode
flutter analyze                                    # Lint check
flutter test                                       # Run tests
```

### **Database Management**
```bash
docker-compose up -d postgres    # Start PostgreSQL
docker-compose down              # Stop all services
docker-compose logs postgres     # View database logs

# Access pgAdmin at http://localhost:8081
# Email: admin@apogee.dev, Password: admin123
```

## 🎮 XP System Documentation

### **Core Mechanics**
The XP system is the heart of Apogee's gamification:

- **Base XP**: Accumulated points until yesterday
- **Today XP**: Raw points earned today (cap: 200 + 25% overflow)
- **Tomorrow XP**: Points during 0-2 AM gap period
- **Total XP**: `Base + Real_Today + Real_Tomorrow`

### **2 AM Deadline Logic**
- Tasks must be completed by 2 AM next day
- **Gap Period (0-2 AM)**: Special handling for late-night users
  - Tasks from "yesterday" → Today XP limit
  - Tasks from "today" → Tomorrow XP limit
- **Daily Reset (2 AM)**: `Base += Real_Today; Today = Tomorrow; Tomorrow = 0`

### **Rewards**
- **Completed (on-time)**: 20 XP + coins
- **Logged (not necessary/didn't do)**: 10 XP
- **Late completion**: 0 XP (coins only)
- **Level formula**: `(level-1)² × 100`

## 🔄 Sync Architecture

### **Offline-First Strategy**
1. **Local Storage**: Hive database for immediate responsiveness
2. **Background Sync**: Periodic synchronization with server
3. **Conflict Resolution**: Server authority with intelligent merging
4. **Data Integrity**: Version tracking and validation

### **Sync Flow**
```dart
// Client requests changes since last sync
GET /api/v1/sync/{userId}?since=2024-01-01T00:00:00Z

// Client uploads local changes
POST /api/v1/sync/{userId}
{
  "changes": {
    "user": {...},
    "taskTemplates": [...],
    "tasks": [...]
  }
}
```

## 🏗️ Team Development Guidelines

### **Code Organization**
- **Models**: Shared between client/server in `shared/models`
- **Services**: Business logic layer
- **Clean Architecture**: Clear separation of concerns
- **English Comments**: All documentation in English

### **Development Workflow**
1. **Local Development**: Use `docker-compose` for full stack
2. **Feature Branches**: Create branches for new features
3. **Testing**: Write tests for business logic
4. **Code Review**: All changes reviewed before merge

### **Database Migrations**
```sql
-- Add new migrations to scripts/migrations/
-- Follow semantic versioning
-- Include rollback scripts
```

## 📊 API Documentation

### **Authentication**
All protected endpoints require JWT token:
```
Authorization: Bearer <jwt-token>
```

### **Key Endpoints**
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `GET /api/v1/users/{userId}` - Get user profile
- `GET /api/v1/sync/{userId}` - Sync data

### **Error Handling**
Standard HTTP status codes with JSON error responses:
```json
{
  "error": "Authentication failed",
  "message": "Invalid credentials",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 🔒 Security Features

- **Password Hashing**: bcrypt with salt
- **JWT Authentication**: Secure token-based auth
- **Rate Limiting**: Prevents API abuse
- **Input Validation**: Server-side validation
- **SQL Injection Protection**: Parameterized queries

## 🚀 Deployment

### **Production Deployment**
```bash
# Build and deploy with Docker
docker-compose -f docker-compose.prod.yml up -d

# Or build manually
cd server
dart compile exe main.dart -o apogee-server
./apogee-server
```

### **Environment Variables**
Copy `.env.example` to `.env` and configure:
```bash
DB_HOST=your-postgres-host
DB_PASSWORD=secure-password
JWT_SECRET=your-jwt-secret
```

## 🔧 Development Notes

### **Current Implementation Status**

**✅ Working Components:**
- Flutter client with full XP system and habit tracking
- PostgreSQL database with Docker setup
- Basic Dart Frog server (health endpoint)
- Shared models with JSON serialization
- Professional repository structure

**🚧 Work in Progress:**
- Server API endpoints (authentication, sync, user management)
- Client-server synchronization
- Shared model imports in server code
- Dart Frog 1.2.3 API compatibility updates

### **Quick Start for Development Team**

1. **For immediate development**: Use the Flutter client standalone
   ```bash
   cd client && flutter run
   ```

2. **For server development**: Start with the basic health endpoint
   ```bash
   cd server && dart_frog dev
   # Visit http://localhost:8080 to see API status
   ```

3. **For database development**: PostgreSQL is ready
   ```bash
   docker-compose up -d postgres
   # Access pgAdmin at http://localhost:8081
   ```

### **Next Development Steps**
1. Fix shared model imports in server (`pubspec.yaml` path dependencies)
2. Update server code for Dart Frog 1.2.3 API compatibility
3. Implement authentication endpoints
4. Add client-server sync service
5. Integrate PostgreSQL connection

## 🧪 Testing

### **Running Tests**
```bash
# Client tests (currently working)
cd client && flutter test

# Server tests (needs setup)
cd server && dart test

# Manual testing
curl http://localhost:8080  # Test server health endpoint
```

## 📈 Performance Considerations

- **Database Indexes**: Optimized for common queries
- **Streak Caching**: O(1) lookups for performance-critical operations
- **Connection Pooling**: Efficient database connections
- **Rate Limiting**: Prevents abuse and ensures stability

## 🤝 Contributing

1. **Setup Development Environment**: Follow Quick Start guide
2. **Create Feature Branch**: `git checkout -b feature/awesome-feature`
3. **Write Tests**: Ensure code coverage
4. **Submit Pull Request**: Include description of changes

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ using Dart & Flutter**