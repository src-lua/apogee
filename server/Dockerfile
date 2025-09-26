# Apogee Server Docker Configuration
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# Copy pubspec files and install dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy source code
COPY . .

# Build the application
RUN dart compile exe main.dart -o server

# Production image
FROM debian:bullseye-slim AS runtime

# Install necessary runtime dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -r -s /bin/false appuser

# Set working directory
WORKDIR /app

# Copy the compiled server
COPY --from=build /app/server ./server

# Change ownership to non-root user
RUN chown appuser:appuser /app/server

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start the server
CMD ["./server"]