# Deployment Guide

This guide covers deploying Apogee to production environments, including server deployment, database setup, and Flutter app distribution.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │  Load Balancer  │    │   PostgreSQL    │
│  (Client Apps)  │    │   (Nginx/ALB)   │    │   Database      │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │     iOS     │ │    │ │    SSL      │ │    │ │   Primary   │ │
│ └─────────────┘ │    │ │  Termination│ │    │ │   Instance  │ │
│ ┌─────────────┐ │◄─▶ │ └─────────────┘ │◄─▶ │ └─────────────┘ │
│ │   Android   │ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ └─────────────┘ │    │ │   API       │ │    │ │   Replica   │ │
│ ┌─────────────┐ │    │ │   Server    │ │    │ │  (Optional) │ │
│ │     Web     │ │    │ │ (Dart Frog) │ │    │ └─────────────┘ │
│ └─────────────┘ │    │ └─────────────┘ │    └─────────────────┘
└─────────────────┘    └─────────────────┘
```

## 🚀 Production Deployment Options

### Option 1: Docker Deployment (Recommended)

The simplest production deployment using Docker containers.

#### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 2+ GB RAM
- 10+ GB disk space

#### Deployment Steps

1. **Clone and Configure**
   ```bash
   git clone https://github.com/your-org/apogee.git
   cd apogee
   cp .env.example .env.production
   ```

2. **Configure Environment Variables**
   ```bash
   # .env.production
   ENVIRONMENT=production

   # Database
   DB_HOST=postgres
   DB_PORT=5432
   DB_NAME=apogee_prod
   DB_USER=apogee_user
   DB_PASSWORD=your-secure-password

   # Security
   JWT_SECRET=your-super-secret-jwt-key-min-32-chars

   # Server
   HOST=0.0.0.0
   PORT=8080

   # Optional: External services
   REDIS_URL=redis://redis:6379
   SENTRY_DSN=your-sentry-dsn
   ```

3. **Create Production Docker Compose**
   ```yaml
   # docker-compose.prod.yml
   version: '3.8'

   services:
     postgres:
       image: postgres:16
       container_name: apogee_postgres_prod
       restart: unless-stopped
       environment:
         POSTGRES_DB: ${DB_NAME}
         POSTGRES_USER: ${DB_USER}
         POSTGRES_PASSWORD: ${DB_PASSWORD}
       volumes:
         - postgres_data:/var/lib/postgresql/data
         - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
       networks:
         - apogee_network
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
         interval: 10s
         timeout: 5s
         retries: 5

     server:
       build:
         context: ./server
         dockerfile: Dockerfile.prod
       container_name: apogee_server_prod
       restart: unless-stopped
       depends_on:
         postgres:
           condition: service_healthy
       env_file:
         - .env.production
       ports:
         - "8080:8080"
       networks:
         - apogee_network
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
         interval: 30s
         timeout: 10s
         retries: 3
         start_period: 60s
       deploy:
         resources:
           limits:
             memory: 512M
           reservations:
             memory: 256M

     nginx:
       image: nginx:alpine
       container_name: apogee_nginx_prod
       restart: unless-stopped
       depends_on:
         - server
       ports:
         - "80:80"
         - "443:443"
       volumes:
         - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
         - ./nginx/ssl:/etc/nginx/ssl:ro
       networks:
         - apogee_network

   volumes:
     postgres_data:

   networks:
     apogee_network:
       driver: bridge
   ```

4. **Deploy**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Option 2: Cloud Platform Deployment

#### Deploy to Google Cloud Run

1. **Build and Push Container**
   ```bash
   # Build server container
   cd server
   docker build -t gcr.io/your-project/apogee-server .
   docker push gcr.io/your-project/apogee-server
   ```

2. **Deploy to Cloud Run**
   ```bash
   gcloud run deploy apogee-server \
     --image gcr.io/your-project/apogee-server \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --memory 512Mi \
     --concurrency 100 \
     --set-env-vars ENVIRONMENT=production \
     --set-env-vars JWT_SECRET=your-secret \
     --set-env-vars DB_HOST=your-db-host
   ```

#### Deploy to AWS ECS

1. **Create Task Definition**
   ```json
   {
     "family": "apogee-server",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "apogee-server",
         "image": "your-account.dkr.ecr.region.amazonaws.com/apogee-server:latest",
         "portMappings": [
           {
             "containerPort": 8080,
             "protocol": "tcp"
           }
         ],
         "environment": [
           {
             "name": "ENVIRONMENT",
             "value": "production"
           }
         ],
         "secrets": [
           {
             "name": "JWT_SECRET",
             "valueFrom": "arn:aws:secretsmanager:region:account:secret:apogee/jwt-secret"
           }
         ]
       }
     ]
   }
   ```

2. **Create ECS Service**
   ```bash
   aws ecs create-service \
     --cluster apogee-cluster \
     --service-name apogee-server \
     --task-definition apogee-server:1 \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[subnet-12345],securityGroups=[sg-12345],assignPublicIp=ENABLED}"
   ```

## 🗄️ Database Setup

### PostgreSQL Production Configuration

1. **Create Production Database**
   ```sql
   -- Connect as superuser
   CREATE USER apogee_user WITH PASSWORD 'secure_password';
   CREATE DATABASE apogee_prod OWNER apogee_user;
   GRANT ALL PRIVILEGES ON DATABASE apogee_prod TO apogee_user;

   -- Connect to apogee_prod database
   \c apogee_prod
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
   ```

2. **Run Database Migrations**
   ```bash
   # From project root
   cd scripts
   psql postgresql://apogee_user:password@localhost:5432/apogee_prod < init.sql
   ```

3. **Production PostgreSQL Configuration**
   ```ini
   # postgresql.conf optimizations
   shared_buffers = 256MB
   effective_cache_size = 1GB
   maintenance_work_mem = 64MB
   checkpoint_completion_target = 0.9
   wal_buffers = 16MB
   default_statistics_target = 100
   random_page_cost = 1.1
   effective_io_concurrency = 200

   # Connection settings
   max_connections = 200

   # Logging
   logging_collector = on
   log_statement = 'mod'
   log_min_duration_statement = 1000
   ```

### Database Backup Strategy

1. **Automated Backups**
   ```bash
   #!/bin/bash
   # backup.sh
   DATE=$(date +%Y%m%d_%H%M%S)
   BACKUP_DIR="/backups"

   pg_dump postgresql://user:pass@host:5432/apogee_prod > \
     $BACKUP_DIR/apogee_backup_$DATE.sql

   # Keep last 7 days
   find $BACKUP_DIR -name "apogee_backup_*.sql" -mtime +7 -delete
   ```

2. **Schedule with Cron**
   ```bash
   # crontab -e
   0 2 * * * /path/to/backup.sh
   ```

## 🔒 Security Configuration

### SSL/TLS Setup

1. **Nginx SSL Configuration**
   ```nginx
   # nginx/nginx.conf
   server {
       listen 80;
       server_name api.apogee.app;
       return 301 https://$server_name$request_uri;
   }

   server {
       listen 443 ssl http2;
       server_name api.apogee.app;

       ssl_certificate /etc/nginx/ssl/cert.pem;
       ssl_certificate_key /etc/nginx/ssl/key.pem;
       ssl_protocols TLSv1.2 TLSv1.3;
       ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
       ssl_prefer_server_ciphers off;

       location / {
           proxy_pass http://server:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

2. **Let's Encrypt SSL Certificate**
   ```bash
   # Install Certbot
   sudo apt install certbot python3-certbot-nginx

   # Generate certificate
   sudo certbot --nginx -d api.apogee.app

   # Auto-renewal
   sudo crontab -e
   0 12 * * * /usr/bin/certbot renew --quiet
   ```

### Security Headers

```nginx
# Add to nginx server block
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

### Environment Secrets Management

1. **Docker Secrets**
   ```yaml
   # docker-compose.prod.yml
   services:
     server:
       secrets:
         - jwt_secret
         - db_password
       environment:
         - JWT_SECRET_FILE=/run/secrets/jwt_secret
         - DB_PASSWORD_FILE=/run/secrets/db_password

   secrets:
     jwt_secret:
       file: ./secrets/jwt_secret.txt
     db_password:
       file: ./secrets/db_password.txt
   ```

2. **Kubernetes Secrets**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: apogee-secrets
   type: Opaque
   data:
     jwt-secret: <base64-encoded-secret>
     db-password: <base64-encoded-password>
   ```

## 📱 Flutter App Distribution

### Build Configuration

1. **Production Build Configuration**
   ```dart
   // lib/config/app_config.dart
   class AppConfig {
     static const String environment = String.fromEnvironment(
       'ENVIRONMENT',
       defaultValue: 'development',
     );

     static const String apiBaseUrl = String.fromEnvironment(
       'API_BASE_URL',
       defaultValue: 'https://api.apogee.app',
     );

     static bool get isProduction => environment == 'production';
     static bool get isDevelopment => environment == 'development';
   }
   ```

2. **Build Scripts**
   ```bash
   #!/bin/bash
   # build_production.sh

   cd client

   # Clean previous builds
   flutter clean
   flutter pub get
   flutter packages pub run build_runner build --delete-conflicting-outputs

   # Build for different platforms
   flutter build apk --release \
     --dart-define=ENVIRONMENT=production \
     --dart-define=API_BASE_URL=https://api.apogee.app

   flutter build ios --release \
     --dart-define=ENVIRONMENT=production \
     --dart-define=API_BASE_URL=https://api.apogee.app

   flutter build web --release \
     --dart-define=ENVIRONMENT=production \
     --dart-define=API_BASE_URL=https://api.apogee.app
   ```

### Android Release

1. **Signing Configuration**
   ```gradle
   // android/app/build.gradle
   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               minifyEnabled true
               shrinkResources true
           }
       }
   }
   ```

2. **Play Store Deployment**
   ```bash
   # Build AAB for Play Store
   flutter build appbundle --release

   # Upload using Play Console or fastlane
   fastlane supply --aab build/app/outputs/bundle/release/app-release.aab
   ```

### iOS Release

1. **Build and Archive**
   ```bash
   # Open in Xcode for signing and deployment
   open ios/Runner.xcworkspace

   # Or use command line
   flutter build ios --release
   cd ios
   xcodebuild -workspace Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     -archivePath build/Runner.xcarchive \
     archive
   ```

2. **App Store Upload**
   ```bash
   # Using Xcode
   xcodebuild -exportArchive \
     -archivePath build/Runner.xcarchive \
     -exportPath build/Runner.ipa \
     -exportOptionsPlist ExportOptions.plist
   ```

### Web Deployment

1. **Build and Deploy**
   ```bash
   # Build web version
   flutter build web --release

   # Deploy to hosting service
   # Firebase Hosting
   firebase deploy --only hosting

   # Netlify
   netlify deploy --prod --dir=build/web

   # AWS S3 + CloudFront
   aws s3 sync build/web/ s3://apogee-web-bucket --delete
   aws cloudfront create-invalidation --distribution-id E1234567890 --paths "/*"
   ```

## 📊 Monitoring and Observability

### Application Monitoring

1. **Health Check Endpoint**
   ```dart
   // server/routes/health.dart
   @Route.get('/health')
   Future<Response> health(RequestContext context) async {
     final dbStatus = await _checkDatabaseConnection();
     final redisStatus = await _checkRedisConnection();

     return Response.json({
       'status': 'healthy',
       'timestamp': DateTime.now().toIso8601String(),
       'version': Platform.environment['APP_VERSION'] ?? 'unknown',
       'services': {
         'database': dbStatus,
         'redis': redisStatus,
       },
       'uptime': _getUptime(),
     });
   }
   ```

2. **Prometheus Metrics**
   ```dart
   // Add to server
   dependencies:
     prometheus_client: ^0.1.0

   // Metrics collection
   final requestCounter = Counter(
     name: 'http_requests_total',
     help: 'Total number of HTTP requests',
     labelNames: ['method', 'endpoint', 'status'],
   );

   final requestDuration = Histogram(
     name: 'http_request_duration_seconds',
     help: 'HTTP request duration',
     labelNames: ['method', 'endpoint'],
   );
   ```

3. **Error Tracking with Sentry**
   ```dart
   // Initialize Sentry
   await SentryFlutter.init(
     (options) {
       options.dsn = 'YOUR_SENTRY_DSN';
       options.environment = AppConfig.environment;
     },
     appRunner: () => runApp(MyApp()),
   );
   ```

### Log Management

1. **Structured Logging**
   ```dart
   // server/lib/utils/logger.dart
   class Logger {
     static void info(String message, {Map<String, dynamic>? extra}) {
       final logEntry = {
         'level': 'info',
         'message': message,
         'timestamp': DateTime.now().toIso8601String(),
         'service': 'apogee-server',
         ...?extra,
       };
       print(jsonEncode(logEntry));
     }
   }
   ```

2. **Log Aggregation (ELK Stack)**
   ```yaml
   # docker-compose.logging.yml
   version: '3.8'
   services:
     elasticsearch:
       image: docker.elastic.co/elasticsearch/elasticsearch:8.0.0
       environment:
         - discovery.type=single-node
         - xpack.security.enabled=false
       ports:
         - "9200:9200"

     logstash:
       image: docker.elastic.co/logstash/logstash:8.0.0
       volumes:
         - ./logstash/pipeline:/usr/share/logstash/pipeline
       ports:
         - "5000:5000"

     kibana:
       image: docker.elastic.co/kibana/kibana:8.0.0
       ports:
         - "5601:5601"
   ```

## 🔄 CI/CD Pipeline

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      - name: Run server tests
        run: |
          cd server
          dart pub get
          dart test
      - name: Run client tests
        run: |
          cd client
          flutter test

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker image
        run: |
          docker build -t apogee-server:${{ github.sha }} server/

      - name: Deploy to production
        run: |
          # Deploy using your preferred method
          # (Docker registry, cloud provider, etc.)
```

### Deployment Checklist

- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] SSL certificates installed
- [ ] Health checks passing
- [ ] Monitoring configured
- [ ] Backup strategy implemented
- [ ] Error tracking enabled
- [ ] Load testing completed
- [ ] Security audit passed
- [ ] Documentation updated

## 🛠️ Maintenance and Updates

### Database Maintenance

1. **Regular Tasks**
   ```bash
   # Weekly vacuum and analyze
   psql -c "VACUUM ANALYZE;" apogee_prod

   # Check index usage
   psql -c "SELECT schemaname, tablename, attname, n_distinct, correlation FROM pg_stats;" apogee_prod

   # Monitor long-running queries
   psql -c "SELECT query, state, query_start FROM pg_stat_activity WHERE state != 'idle';" apogee_prod
   ```

2. **Performance Monitoring**
   ```sql
   -- Find slow queries
   SELECT query, mean_time, calls, total_time
   FROM pg_stat_statements
   ORDER BY mean_time DESC
   LIMIT 10;

   -- Check table sizes
   SELECT
     schemaname,
     tablename,
     pg_size_pretty(pg_total_relation_size(tablename::regclass)) as size
   FROM pg_tables
   WHERE schemaname = 'public'
   ORDER BY pg_total_relation_size(tablename::regclass) DESC;
   ```

### Application Updates

1. **Rolling Deployment**
   ```bash
   # Zero-downtime deployment
   docker-compose -f docker-compose.prod.yml pull server
   docker-compose -f docker-compose.prod.yml up -d --no-deps server
   ```

2. **Database Migration Process**
   ```bash
   # 1. Backup current database
   pg_dump apogee_prod > backup_pre_migration.sql

   # 2. Apply migrations
   psql apogee_prod < migrations/001_new_feature.sql

   # 3. Verify application health
   curl -f http://localhost:8080/health
   ```

### Scaling Considerations

1. **Horizontal Scaling**
   ```yaml
   # docker-compose.scale.yml
   services:
     server:
       deploy:
         replicas: 3
         resources:
           limits:
             memory: 512M

     nginx:
       # Load balancer configuration
       volumes:
         - ./nginx/upstream.conf:/etc/nginx/conf.d/upstream.conf
   ```

2. **Database Read Replicas**
   ```yaml
   services:
     postgres-replica:
       image: postgres:16
       environment:
         PGUSER: replicator
         POSTGRES_PASSWORD: replica_password
         POSTGRES_MASTER_SERVICE: postgres
         POSTGRES_REPLICA_USER: replicator
         POSTGRES_REPLICA_PASSWORD: replica_password
   ```

---

## 📚 Additional Resources

- **Server Configuration**: See `server/Dockerfile.prod`
- **Client Build Scripts**: See `client/build_scripts/`
- **Infrastructure as Code**: See `infrastructure/` directory
- **Monitoring Dashboards**: See `monitoring/grafana/`

---

*This document is part of the Apogee technical documentation. For questions or clarifications, please refer to the [Contributing Guide](../CONTRIBUTING.md).*