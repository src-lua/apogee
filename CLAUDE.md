# Apogee - Habit Gamification App

Flutter-based habit tracker with positive reinforcement mechanics and advanced XP system.

## Quick Commands
```bash
flutter pub get                                    # Install deps
flutter packages pub run build_runner build       # Generate Hive adapters
flutter run                                        # Dev mode
flutter analyze                                    # Lint
flutter clean                                      # Clean build
```

## Architecture Overview

**Core Systems:**
- Triple economy: Coins (rewards), XP (progression), Diamonds (level rewards)
- Template-based task system with recurrency patterns
- Advanced XP tracking with 2 AM deadline and gap period logic
- Local-first with Hive NoSQL storage

**Key Files:**
- `lib/main.dart` - Main app and UI (ApogeeHomePage)
- `lib/services/user_service.dart` - XP/currency/level management
- `lib/services/task_service.dart` - Task templates and daily generation
- `lib/pages/task_management_page.dart` - Template CRUD interface

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

## Models & Storage
- `@HiveType` models with generated TypeAdapters
- UTC normalized day keys: `YYYY-MM-DDTHH:mm:ss.sssZ`
- Templates stored as list in `task_templates` key
- Daily tasks stored per ISO date key

## Development Notes
- Always run build_runner after model changes
- 2 AM deadline applies to both task lateness and XP reset
- Portuguese locale for calendar display
- Windows Defender may interfere with Flutter tools