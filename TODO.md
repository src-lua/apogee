# Apogee Development TODO

## 🏗️ Infrastructure & Architecture

### Server-Client Integration (Priority: High)
- [ ] **Configure shared models in server**: Fix `pubspec.yaml` path dependencies to import shared models
- [ ] **Implement HTTP client service**: Create service in `client/lib/services/` for API communication
- [ ] **Add server configuration**: Environment-based server URL configuration (localhost:8080 for dev)
- [ ] **Connection status handling**: Implement online/offline detection and fallback behavior
- [ ] **Error handling layer**: Standardized error handling for network requests and server responses

### Authentication System
- [ ] **Server auth endpoints**: Implement `/api/v1/auth/register` and `/api/v1/auth/login`
- [ ] **JWT token management**: Secure storage and refresh logic in Flutter client
- [ ] **Protected route middleware**: Server-side authentication validation for protected endpoints
- [ ] **Client auth state**: Global authentication state management (Provider/Bloc)

### Data Synchronization
- [ ] **Sync service architecture**: Design bidirectional sync between Hive (local) and PostgreSQL (server)
- [ ] **Conflict resolution**: Implement server-authority conflict resolution with intelligent merging
- [ ] **Sync endpoints**: `/api/v1/sync/{userId}` for uploading/downloading changes
- [ ] **Delta sync**: Only sync changes since last sync timestamp (performance optimization)
- [ ] **Sync progress UI**: User feedback during synchronization process

## 🔧 Server Development

### API Endpoints
- [ ] **User management**: CRUD operations for user profiles and preferences
- [ ] **Task templates**: Server-side storage and management of task templates
- [ ] **Daily tasks**: Task instance management with proper date handling
- [ ] **XP calculations**: Server-side validation of XP logic and level calculations
- [ ] **Statistics endpoints**: Aggregated data for streaks, weekly progress, etc.

### Database Layer
- [ ] **ORM integration**: Set up database models and connection pooling
- [ ] **Migration system**: Database schema versioning and migration scripts
- [ ] **Data validation**: Server-side validation matching shared model constraints
- [ ] **Performance optimization**: Database indexes for common query patterns

### Infrastructure
- [ ] **Rate limiting**: Implement rate limiting middleware to prevent API abuse
- [ ] **Logging system**: Structured logging for debugging and monitoring
- [ ] **Health checks**: Enhanced health endpoints for monitoring
- [ ] **API documentation**: OpenAPI/Swagger documentation for all endpoints

## 📱 Client Development

### Network Layer
- [ ] **Retrofit/Dio setup**: HTTP client with proper error handling and timeouts
- [ ] **Response models**: Map server responses to client models
- [ ] **Caching strategy**: Smart caching for reduced network requests
- [ ] **Offline queue**: Queue failed requests for retry when connection restored

### UI/UX Improvements
- [ ] **Connection indicator**: Visual indicator of online/offline status
- [ ] **Sync status**: Show last sync time and sync in progress indicators
- [ ] **Error messages**: User-friendly error messages for network failures
- [ ] **Loading states**: Proper loading indicators during API calls

### Data Management
- [ ] **Hybrid storage**: Seamless integration between local Hive and server data
- [ ] **Data consistency**: Ensure UI always shows most current data (local or server)
- [ ] **Background sync**: Automatic sync when app returns to foreground

## 🎮 Feature Development

### Gamification Features
- [ ] **Streak visualization**: Show task streaks in dedicated UI section
- [ ] **Coin store**: Virtual store for spending coins on rewards/customizations
- [ ] **Achievement system**: Unlock achievements for milestones and consistency
- [ ] **Leaderboards**: Optional social features for friendly competition

### Task Management
- [ ] **Custom task duration**: Allow users to set custom time estimates for tasks
- [ ] **Non-recurring tasks**: Handle one-time tasks vs recurring task templates
- [ ] **Task categories**: Organize tasks by categories with color coding
- [ ] **Task templates library**: Predefined templates for common habit types

### Analytics & Insights
- [ ] **Progress charts**: Visual charts for XP progress, completion rates, streaks
- [ ] **Weekly/monthly reports**: Automated progress summaries
- [ ] **Habit insights**: AI-powered insights about habit patterns
- [ ] **Export data**: Allow users to export their data (JSON/CSV)

## 💰 Economy System

### Coin Management
- [ ] **Negative coin handling**: Prevent or gracefully handle negative coin balances
- [ ] **Coin transaction log**: Track all coin earning and spending with audit trail
- [ ] **Coin rewards balancing**: Fine-tune coin rewards for different task completions
- [ ] **Refund system**: Handle coin refunds when tasks are marked as undone

### Rewards & Store
- [ ] **Store items**: Design virtual items, themes, or features users can purchase
- [ ] **Daily bonuses**: Login streaks and daily bonus coins
- [ ] **Level rewards**: Diamond rewards for reaching new levels

## 🧪 Quality & Testing

### Testing Infrastructure
- [ ] **Unit tests**: Comprehensive tests for business logic (XP calculations, sync logic)
- [ ] **Integration tests**: Test server-client communication
- [ ] **Widget tests**: Test critical UI components and user flows
- [ ] **End-to-end tests**: Full user journey testing

### Code Quality
- [ ] **Linting rules**: Enforce consistent code style across client and server
- [ ] **Documentation**: Inline documentation for complex business logic
- [ ] **Performance monitoring**: Monitor app performance and server response times
- [ ] **Error tracking**: Implement crash reporting and error tracking

## 🚀 Deployment & DevOps

### Production Readiness
- [ ] **Environment configuration**: Separate dev/staging/production configurations
- [ ] **Database migrations**: Production-safe migration system
- [ ] **Security audit**: Review authentication, data validation, and security practices
- [ ] **Performance testing**: Load testing for server endpoints
- [ ] **Backup strategy**: Automated database backups and recovery procedures

### Monitoring
- [ ] **Application monitoring**: Server health, response times, error rates
- [ ] **User analytics**: Track app usage patterns (privacy-compliant)
- [ ] **Alerting system**: Notifications for critical system issues

---

## 📋 Next Sprint Priorities

1. **Server-Client Integration**: Focus on getting basic communication working
2. **Authentication**: Implement secure user login/registration
3. **Basic Sync**: Simple one-way sync from client to server
4. **Error Handling**: Robust error handling for network issues

---

**Legend**:
- Priority: High = Critical for MVP
- Priority: Medium = Important for user experience
- Priority: Low = Nice-to-have features