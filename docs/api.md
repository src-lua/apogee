# API Documentation

This document provides comprehensive documentation for the Apogee REST API, built with Dart Frog and designed for the Flutter client application.

## 📡 Base Information

- **Base URL**: `http://localhost:8080` (development)
- **Version**: v1
- **Content Type**: `application/json`
- **Authentication**: JWT Bearer tokens

## 🔐 Authentication

### Overview

All protected endpoints require JWT authentication. Public endpoints include user registration and login.

### JWT Token Format

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Lifecycle

- **Expiration**: 7 days
- **Refresh**: Automatic refresh before expiration
- **Storage**: Secure storage on client (Flutter Secure Storage)

---

## 🚪 Authentication Endpoints

### Register User

Create a new user account.

```http
POST /api/v1/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "id": "uuid-v4",
    "email": "user@example.com",
    "name": "John Doe",
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Error Responses:**
```json
// 400 Bad Request - Email already exists
{
  "error": "Registration failed",
  "message": "Email already registered",
  "code": "EMAIL_EXISTS"
}

// 400 Bad Request - Validation error
{
  "error": "Validation failed",
  "message": "Password must be at least 8 characters",
  "code": "INVALID_PASSWORD"
}
```

### Login User

Authenticate existing user.

```http
POST /api/v1/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": "uuid-v4",
    "email": "user@example.com",
    "name": "John Doe",
    "lastLoginAt": "2024-01-01T00:00:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Error Responses:**
```json
// 401 Unauthorized - Invalid credentials
{
  "error": "Authentication failed",
  "message": "Invalid email or password",
  "code": "INVALID_CREDENTIALS"
}

// 429 Too Many Requests - Rate limited
{
  "error": "Rate limit exceeded",
  "message": "Too many login attempts. Try again in 15 minutes",
  "code": "RATE_LIMITED"
}
```

### Refresh Token

Refresh an existing JWT token.

```http
POST /api/v1/auth/refresh
Authorization: Bearer <current-token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresAt": "2024-01-08T00:00:00Z"
}
```

### Logout

Invalidate current session token.

```http
POST /api/v1/auth/logout
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 👤 User Management

### Get User Profile

Retrieve current user's profile information.

```http
GET /api/v1/users/{userId}
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "id": "uuid-v4",
    "email": "user@example.com",
    "name": "John Doe",
    "avatar": null,
    "createdAt": "2024-01-01T00:00:00Z",
    "preferences": {
      "timezone": "America/New_York",
      "theme": "dark",
      "notifications": true
    },
    "gamification": {
      "level": 5,
      "totalXP": 1250,
      "todayXP": 80,
      "tomorrowXP": 0,
      "coins": 450,
      "diamonds": 25,
      "streaks": {
        "current": 7,
        "longest": 15
      }
    }
  }
}
```

### Update User Profile

Update user profile information.

```http
PUT /api/v1/users/{userId}
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "name": "John Smith",
  "preferences": {
    "timezone": "Europe/London",
    "theme": "light",
    "notifications": false
  }
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "user": {
    // Updated user object
  }
}
```

### Delete User Account

Permanently delete user account and all associated data.

```http
DELETE /api/v1/users/{userId}
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Account deleted successfully"
}
```

---

## 📋 Task Templates

### Get Task Templates

Retrieve all task templates for a user.

```http
GET /api/v1/users/{userId}/templates
Authorization: Bearer <token>
```

**Query Parameters:**
- `active` (boolean): Filter by active status (default: all)
- `category` (string): Filter by category

**Response (200 OK):**
```json
{
  "success": true,
  "templates": [
    {
      "id": "uuid-v4",
      "userId": "uuid-v4",
      "title": "Morning Exercise",
      "description": "30 minutes of cardio or strength training",
      "category": "fitness",
      "difficulty": 1,
      "xpReward": 20,
      "coinReward": 10,
      "recurrencyType": "daily",
      "recurrencyConfig": {
        "daysOfWeek": [1, 2, 3, 4, 5], // Monday to Friday
        "times": ["07:00"]
      },
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    }
  ],
  "total": 1
}
```

### Create Task Template

Create a new recurring task template.

```http
POST /api/v1/users/{userId}/templates
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "title": "Evening Reading",
  "description": "Read for 30 minutes before bed",
  "category": "education",
  "difficulty": 1,
  "recurrencyType": "daily",
  "recurrencyConfig": {
    "daysOfWeek": [1, 2, 3, 4, 5, 6, 7],
    "times": ["21:00"]
  }
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Template created successfully",
  "template": {
    // Complete template object
  }
}
```

### Update Task Template

Update an existing task template.

```http
PUT /api/v1/users/{userId}/templates/{templateId}
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "title": "Updated Title",
  "isActive": false
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Template updated successfully",
  "template": {
    // Updated template object
  }
}
```

### Delete Task Template

Delete a task template and optionally clean up generated tasks.

```http
DELETE /api/v1/users/{userId}/templates/{templateId}
Authorization: Bearer <token>
```

**Query Parameters:**
- `cleanupTasks` (boolean): Delete generated tasks (default: false)

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Template deleted successfully"
}
```

---

## ✅ Tasks

### Get Tasks

Retrieve tasks for a specific date range.

```http
GET /api/v1/users/{userId}/tasks
Authorization: Bearer <token>
```

**Query Parameters:**
- `startDate` (ISO date): Start of date range (required)
- `endDate` (ISO date): End of date range (required)
- `status` (string): Filter by status (`pending`, `completed`, `logged`, `late`)
- `templateId` (UUID): Filter by template

**Response (200 OK):**
```json
{
  "success": true,
  "tasks": [
    {
      "id": "template-id_2024-01-01",
      "templateId": "uuid-v4",
      "userId": "uuid-v4",
      "date": "2024-01-01",
      "status": "completed",
      "completedAt": "2024-01-01T07:30:00Z",
      "xpEarned": 20,
      "coinsEarned": 10,
      "notes": "Great workout this morning!",
      "template": {
        "title": "Morning Exercise",
        "category": "fitness"
      }
    }
  ],
  "total": 1,
  "summary": {
    "totalXP": 20,
    "totalCoins": 10,
    "completionRate": 1.0,
    "streakData": {
      "current": 7,
      "longest": 15
    }
  }
}
```

### Update Task Status

Update the status and completion details of a task.

```http
PUT /api/v1/users/{userId}/tasks/{taskId}
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "status": "completed",
  "completedAt": "2024-01-01T07:30:00Z",
  "notes": "Completed 45 minutes of running"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Task updated successfully",
  "task": {
    // Updated task object
  },
  "xpUpdate": {
    "xpEarned": 20,
    "coinsEarned": 10,
    "newTotalXP": 1270,
    "levelUp": false
  }
}
```

### Batch Update Tasks

Update multiple tasks in a single request.

```http
PUT /api/v1/users/{userId}/tasks/batch
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "updates": [
    {
      "taskId": "template-1_2024-01-01",
      "status": "completed",
      "completedAt": "2024-01-01T07:30:00Z"
    },
    {
      "taskId": "template-2_2024-01-01",
      "status": "logged",
      "notes": "Didn't have time today"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Tasks updated successfully",
  "results": [
    {
      "taskId": "template-1_2024-01-01",
      "success": true,
      "xpEarned": 20
    },
    {
      "taskId": "template-2_2024-01-01",
      "success": true,
      "xpEarned": 10
    }
  ],
  "totalXPEarned": 30,
  "newTotalXP": 1300
}
```

---

## 📊 Statistics

### Get User Statistics

Retrieve comprehensive user statistics and analytics.

```http
GET /api/v1/users/{userId}/stats
Authorization: Bearer <token>
```

**Query Parameters:**
- `period` (string): Time period (`week`, `month`, `year`, `all`)
- `categories` (string[]): Filter by categories

**Response (200 OK):**
```json
{
  "success": true,
  "stats": {
    "overview": {
      "totalTasks": 450,
      "completedTasks": 380,
      "completionRate": 0.844,
      "totalXP": 7600,
      "totalCoins": 3800,
      "currentLevel": 8,
      "streaks": {
        "current": 12,
        "longest": 28
      }
    },
    "daily": {
      "averageTasksPerDay": 3.2,
      "averageXPPerDay": 65,
      "bestDay": {
        "date": "2024-01-15",
        "tasksCompleted": 8,
        "xpEarned": 160
      }
    },
    "categories": [
      {
        "name": "fitness",
        "completionRate": 0.92,
        "totalTasks": 120,
        "totalXP": 2400
      }
    ],
    "trends": {
      "weeklyProgress": [85, 90, 78, 95, 88, 92, 87], // Last 7 days completion %
      "monthlyXP": [1250, 1380, 1420, 1650] // Last 4 weeks XP
    }
  }
}
```

### Get Leaderboard

Retrieve leaderboard data (if social features enabled).

```http
GET /api/v1/leaderboard
Authorization: Bearer <token>
```

**Query Parameters:**
- `period` (string): Time period (`week`, `month`, `all`)
- `type` (string): Leaderboard type (`xp`, `streaks`, `completion`)

**Response (200 OK):**
```json
{
  "success": true,
  "leaderboard": [
    {
      "rank": 1,
      "userId": "uuid-v4",
      "name": "John Doe",
      "score": 1500,
      "avatar": null
    }
  ],
  "userRank": {
    "rank": 15,
    "score": 1200,
    "totalUsers": 1000
  }
}
```

---

## 🔄 Synchronization

### Upload Changes

Upload local changes to the server for synchronization.

```http
POST /api/v1/sync/{userId}/upload
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "clientTimestamp": "2024-01-01T12:00:00Z",
  "lastSyncTimestamp": "2024-01-01T08:00:00Z",
  "changes": [
    {
      "entityType": "task",
      "entityId": "template-1_2024-01-01",
      "changeType": "update",
      "data": {
        "status": "completed",
        "completedAt": "2024-01-01T07:30:00Z"
      },
      "timestamp": "2024-01-01T07:30:00Z"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "serverTimestamp": "2024-01-01T12:00:05Z",
  "results": [
    {
      "entityId": "template-1_2024-01-01",
      "success": true,
      "conflict": false
    }
  ],
  "conflicts": [] // Any conflicted changes requiring resolution
}
```

### Download Changes

Download server changes since last synchronization.

```http
GET /api/v1/sync/{userId}/changes
Authorization: Bearer <token>
```

**Query Parameters:**
- `since` (ISO timestamp): Last sync timestamp (optional)

**Response (200 OK):**
```json
{
  "success": true,
  "serverTimestamp": "2024-01-01T12:00:05Z",
  "changes": [
    {
      "entityType": "taskTemplate",
      "entityId": "uuid-v4",
      "changeType": "create",
      "data": {
        // Complete template object
      },
      "timestamp": "2024-01-01T10:30:00Z"
    }
  ],
  "hasMore": false
}
```

---

## 🏪 Store (Future Feature)

### Get Store Items

Retrieve available store items for purchase with coins.

```http
GET /api/v1/store/items
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "items": [
    {
      "id": "theme-ocean",
      "name": "Ocean Theme",
      "description": "Beautiful ocean-inspired color theme",
      "category": "themes",
      "price": 100,
      "currency": "coins",
      "available": true,
      "owned": false
    }
  ]
}
```

### Purchase Item

Purchase a store item with coins.

```http
POST /api/v1/store/purchase
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "itemId": "theme-ocean"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Item purchased successfully",
  "transaction": {
    "id": "uuid-v4",
    "itemId": "theme-ocean",
    "cost": 100,
    "remainingCoins": 350
  }
}
```

---

## 🚨 Error Handling

### Standard Error Response Format

All errors follow a consistent format:

```json
{
  "error": "Error category",
  "message": "Human-readable error description",
  "code": "MACHINE_READABLE_CODE",
  "timestamp": "2024-01-01T12:00:00Z",
  "requestId": "uuid-v4"
}
```

### HTTP Status Codes

| Code | Description | Usage |
|------|-------------|-------|
| 200 | OK | Successful GET, PUT requests |
| 201 | Created | Successful POST requests |
| 400 | Bad Request | Invalid request format or parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Data conflict (e.g., duplicate email) |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limiting |
| 500 | Internal Server Error | Server error |

### Common Error Codes

| Code | Description |
|------|-------------|
| `INVALID_TOKEN` | JWT token is invalid or expired |
| `EMAIL_EXISTS` | Email already registered |
| `INVALID_CREDENTIALS` | Login credentials are incorrect |
| `VALIDATION_ERROR` | Request validation failed |
| `RATE_LIMITED` | Too many requests from client |
| `RESOURCE_NOT_FOUND` | Requested resource doesn't exist |
| `PERMISSION_DENIED` | User lacks required permissions |
| `SYNC_CONFLICT` | Data synchronization conflict |

### Rate Limiting

Rate limits are applied per endpoint:

- **Authentication**: 5 requests per minute
- **General API**: 100 requests per minute
- **Sync endpoints**: 20 requests per minute

Rate limit headers:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

---

## 🔧 Development Tools

### Health Check

Check API server health and status.

```http
GET /health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "version": "1.0.0",
  "database": "connected",
  "uptime": "2d 4h 15m"
}
```

### API Documentation

Get OpenAPI specification.

```http
GET /api/docs
```

Returns OpenAPI 3.0 specification for the API.

---

## 📝 Examples

### Complete Task Flow

```bash
# 1. Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# 2. Get today's tasks
curl -X GET "http://localhost:8080/api/v1/users/{userId}/tasks?startDate=2024-01-01&endDate=2024-01-01" \
  -H "Authorization: Bearer {token}"

# 3. Complete a task
curl -X PUT http://localhost:8080/api/v1/users/{userId}/tasks/{taskId} \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"status":"completed","completedAt":"2024-01-01T07:30:00Z"}'

# 4. Sync changes
curl -X POST http://localhost:8080/api/v1/sync/{userId}/upload \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"changes":[...]}'
```

### JavaScript/TypeScript Example

```typescript
class ApogeeAPI {
  private baseURL = 'http://localhost:8080/api/v1';
  private token: string | null = null;

  async login(email: string, password: string) {
    const response = await fetch(`${this.baseURL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    const data = await response.json();
    if (data.success) {
      this.token = data.token;
    }
    return data;
  }

  async getTasks(userId: string, startDate: string, endDate: string) {
    const response = await fetch(
      `${this.baseURL}/users/${userId}/tasks?startDate=${startDate}&endDate=${endDate}`,
      {
        headers: { 'Authorization': `Bearer ${this.token}` },
      }
    );
    return response.json();
  }

  async completeTask(userId: string, taskId: string) {
    const response = await fetch(`${this.baseURL}/users/${userId}/tasks/${taskId}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        status: 'completed',
        completedAt: new Date().toISOString(),
      }),
    });
    return response.json();
  }
}
```

---

## 📚 Additional Resources

- **Server Implementation**: See `server/routes/` directory
- **Shared Models**: See `shared/models/lib/` directory
- **Client Integration**: See `client/lib/services/api_service.dart`
- **Sync Architecture**: See [Sync Architecture Documentation](sync-architecture.md)

---

*This document is part of the Apogee technical documentation. For questions or clarifications, please refer to the [Contributing Guide](../CONTRIBUTING.md).*