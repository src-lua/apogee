# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Apogee is a Flutter-based habit and routine gamification application designed to transform habit-building into a gratifying, visually rewarding journey. The app focuses on positive reinforcement mechanics rather than punitive systems.

### Core Mechanics
- **Dual Economy**: Coins (user-controlled currency), XP (earned through task completion), and Diamonds (premium currency from leveling up)
- **Task System**: Daily task templates with completion tracking and point rewards
- **Calendar Integration**: Visual progress tracking with color-coded completion indicators
- **Local Persistence**: All data stored locally using Hive database

## Development Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Run code generation for Hive models
flutter packages pub run build_runner build

# Run the app (development)
flutter run

# Build for release
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build artifacts
flutter clean
```

### Platform-Specific Development
- **Primary Development Environment**: Android Emulator (due to Samsung S23/Android 15 Beta compatibility issues)
- **Windows**: Potential Windows Defender conflicts - may need security exceptions for Flutter tools

## Architecture

### Data Layer
- **Local Storage**: Hive NoSQL database (`apogee_data` box)
- **Models**: Located in `lib/models/`
  - `Task` model with Hive annotations and generated TypeAdapter
  - Data persistence includes task completion status and user points

### Application Structure
- **Single-screen MVP**: All functionality currently in `ApogeeHomePage` (main.dart:33)
- **State Management**: StatefulWidget with manual state updates
- **Data Flow**: Direct Hive box operations for persistence

### Key Data Patterns
- **Task Storage**: Tasks stored per day using ISO date strings as keys
- **Daily Templates**: Hardcoded template tasks copied to each new day
- **Point System**: Real-time point calculation with persistence on task completion

### UI Components
- **Calendar**: `table_calendar` package with Portuguese locale support
- **Task List**: Dynamic ListView with checkbox interactions
- **Visual Feedback**: Color-coded progress indicators on calendar days

## Dependencies

### Core Dependencies
- `flutter`: Main framework
- `hive` & `hive_flutter`: Local NoSQL database
- `table_calendar`: Calendar widget with customization
- `intl`: Internationalization support (Portuguese)

### Development Dependencies
- `hive_generator`: Code generation for Hive TypeAdapters
- `build_runner`: Code generation runner
- `flutter_lints`: Dart/Flutter linting rules

## Code Generation

The project uses Hive code generation for database models:

```bash
# Generate TypeAdapters when models change
flutter packages pub run build_runner build

# Watch mode for continuous generation
flutter packages pub run build_runner watch
```

**Important**: Always run code generation after modifying models with `@HiveType` annotations.

## Development Notes

### Current State (MVP)
- Single-screen application with hardcoded task templates
- Basic CRUD operations for task completion tracking
- Calendar-based day selection and progress visualization
- Local-only data storage

### Planned Architecture Evolution
- Modular task management system with user-defined templates
- Rewards shop implementation for coin spending
- Cloud synchronization with Firebase/Supabase
- Multi-screen navigation and state management refactoring

### Critical Implementation Details
- Task identification relies on name matching (lib/main.dart:86)
- Day normalization uses UTC to avoid timezone issues (lib/main.dart:64)
- Points are calculated and persisted immediately on task toggle
- Calendar markers show completion percentage with color interpolation