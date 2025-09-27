# Apogee - Professional Habit Tracker

Professional client-server habit tracker built with Flutter and Dart, featuring offline-first sync and advanced XP mechanics.

## Quick Commands

### **Development Setup**
```bash
# Start database
docker-compose up -d postgres

# Start server (Terminal 1)
cd server
dart pub get
dart pub global activate dart_frog_cli
dart_frog dev                                      # Server on port 8080

# Start client (Terminal 2)
cd client
flutter pub get
flutter packages pub run build_runner build
flutter run -d chrome --web-port 3000             # Web on port 3000
# OR: flutter run                                  # Mobile/desktop
```

### **Client (Flutter)**
```bash
cd client
flutter pub get                                    # Install dependencies
flutter packages pub run build_runner build        # Generate Hive adapters
flutter run -d chrome --web-port 3000             # Web development
flutter run                                        # Mobile/desktop development
flutter analyze                                    # Lint check
flutter test                                       # Run tests
flutter test --coverage                           # Tests with coverage
```

### **Server (Dart Frog)**
```bash
cd server
dart pub get                                       # Install dependencies
dart_frog dev                                     # Development server (port 8080)
dart analyze                                      # Lint check
dart test                                         # Run tests
dart compile exe main.dart                        # Production build
```

### **Database & Infrastructure**
```bash
docker-compose up -d postgres                     # Start PostgreSQL
docker-compose up -d                              # Start full stack
docker-compose down                               # Stop all services
docker-compose logs postgres                      # View database logs
docker-compose logs server                        # View server logs

# Database admin: http://localhost:8081 (admin@apogee.dev / admin123)
```

### **Shared Models**
```bash
cd shared/models
dart pub get && dart run build_runner build       # Generate JSON serialization
```

### **Documentation & Tools**
```bash
# Health check
curl http://localhost:8080/health

# View documentation
open docs/                                        # Browse documentation files
open README.md                                   # Quick start guide
open CONTRIBUTING.md                             # Contribution guidelines
open TODO.md                                     # Development roadmap
```

## Architecture Overview

**Pure Dart Stack:**
- **Client**: Flutter with offline-first capabilities (Hive)
- **Server**: Dart Frog API with PostgreSQL
- **Shared**: Common models and utilities
- **Sync**: Conflict resolution with server authority

**Core Systems:**
- Triple economy: Coins (rewards), XP (progression), Diamonds (level rewards)
- Template-based task system with complex recurrency patterns
- Advanced XP tracking with 2 AM deadline and gap period logic
- Client-server sync with offline-first architecture

**Key Directories:**
- `client/lib/` - Flutter app (UI, local services, Hive storage)
- `server/lib/` - API server (auth, database, sync endpoints)
- `shared/models/lib/` - Common data models with JSON serialization
- `scripts/` - Database initialization and deployment scripts
- `docs/` - Comprehensive technical documentation
- `CONTRIBUTING.md` - Team development guidelines and workflows
- `TODO.md` - Current development roadmap and priorities

## XP System (Critical)

**Architecture:**
```
XP = Base XP (until yesterday)
Today_XP = Raw XP earned today
Tomorrow_XP = Raw XP during 0-2 AM gap
Real_Today_XP = Today_XP capped at 200 + 25% overflow
Real_Tomorrow_XP = Tomorrow_XP capped at 200 + 25% overflow
Total_XP = XP + Real_Today_XP + Real_Tomorrow_XP
```

**Gap Period (0-2 AM):**
- Tasks from yesterday's calendar day → Today_XP
- Tasks from today's calendar day → Tomorrow_XP

**Daily Reset (2 AM):**
```
XP += Real_Today_XP
Today_XP = Tomorrow_XP
Tomorrow_XP = 0
```

**Rewards:**
- Completed (on-time): 20 XP
- Logged (not necessary/not did): 10 XP
- Late completion: 0 XP
- Level formula: (level-1)² × 100

## Key Behaviors

**Future Tasks:** Lock icon, no status changes allowed
**Level Display:** Circular progress indicator with tooltip
**Gap Period UI:** Special tooltip showing dual limits
**Template Changes:** Auto-regenerate affected days
**Task ID Format:** `{template_id}_{day_iso_string}`

## Data Architecture

**Client Storage (Hive):**
- Local-first with `@HiveType` models and generated TypeAdapters
- UTC normalized day keys: `YYYY-MM-DDTHH:mm:ss.sssZ`
- Templates stored as list in `task_templates` key
- Daily tasks stored per ISO date key
- Sync metadata for conflict resolution

**Server Storage (PostgreSQL):**
- Relational schema with JSONB support for flexible data
- Foreign key constraints and database-level validation
- Optimized indexes for performance
- Sync audit log for change tracking

**Shared Models:**
- `User` - User profile with gamification data
- `TaskTemplate` - Template for recurring task generation
- `Task` - Individual task instances
- `TaskStatus` - Enum for task states (pending, completed, etc.)
- `SyncData` - Metadata for synchronization and conflict resolution

## Development Notes

**Critical Workflows:**
- Always run `build_runner build` after model changes in any package
- 2 AM deadline applies to both task lateness and XP reset logic
- Server has final authority in sync conflicts
- Use shared models package for consistency between client/server

**Documentation Structure:**
- `README.md` - Quick start and project overview
- `docs/xp-system.md` - Complete XP mechanics and calculations
- `docs/sync-architecture.md` - Offline-first sync implementation
- `docs/api.md` - Complete REST API reference
- `docs/deployment.md` - Production deployment guide
- `docs/development.md` - Performance, security, testing guidelines
- `CONTRIBUTING.md` - Team workflows and contribution process
- `TODO.md` - Current development priorities and roadmap

**Team Development:**
- All comments and documentation must be in English
- Follow clean architecture principles
- Shared models eliminate duplication between client/server
- PostgreSQL provides ACID compliance for data integrity
- See `CONTRIBUTING.md` for detailed development guidelines

**Performance Considerations:**
- Streak calculations are cached with O(1) lookups
- Database queries use proper indexes
- Rate limiting prevents API abuse
- Offline-first ensures responsive UI
- See `docs/development.md` for comprehensive performance guidelines

**Quick References:**
- Port configuration: Server (8080), Web client (3000), pgAdmin (8081)
- Health check: `curl http://localhost:8080/health`
- Database admin: http://localhost:8081 (admin@apogee.dev / admin123)
- For detailed setup, see documentation in `docs/` directory