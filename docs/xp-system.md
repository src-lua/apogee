# XP System Documentation

The Experience Point (XP) system is the core gamification mechanic in Apogee, designed to motivate consistent habit formation through progressive rewards and level advancement.

## 🎯 System Overview

The XP system uses a sophisticated multi-component structure to handle real-world complexities like late-night task completion and daily transitions.

### Core Components

```
XP = Base XP (until yesterday)
Today_XP = Raw XP earned today
Tomorrow_XP = Raw XP during 0-2 AM gap
Real_Today_XP = Today_XP capped at 200 + 25% overflow
Real_Tomorrow_XP = Tomorrow_XP capped at 200 + 25% overflow
Total_XP = XP + Real_Today_XP + Real_Tomorrow_XP
```

## ⏰ Daily Rhythm & 2 AM Deadline

### Why 2 AM Deadline?
- **Natural sleep cycle**: Aligns with typical bedtime routines
- **Grace period**: Accommodates late-night users without breaking daily streaks
- **Psychological boundary**: Clear daily cutoff that's not too strict

### Gap Period (Midnight to 2 AM)

During the 0-2 AM window, task completion dates are interpreted intelligently:

- **Tasks from "yesterday"** (calendar date) → Count toward **Today_XP**
- **Tasks from "today"** (calendar date) → Count toward **Tomorrow_XP**

**Example:**
```
Current time: 1:30 AM on March 15th

Task completed at 1:30 AM:
- If task was for March 14th → Today_XP  (yesterday's calendar day)
- If task was for March 15th → Tomorrow_XP (today's calendar day)
```

### Daily Reset Logic (2 AM)

At 2:00 AM sharp, the system performs the daily transition:

```javascript
// Daily reset algorithm
XP += Real_Today_XP          // Add today's earned XP to base
Today_XP = Tomorrow_XP       // Tomorrow becomes today
Tomorrow_XP = 0              // Reset tomorrow counter
```

## 📊 XP Calculation & Limits

### Daily XP Limits

**Base Limit**: 200 XP per day
**Overflow**: Additional 25% (50 XP maximum)
**Total Daily Cap**: 250 XP

### XP Earning Rules

| Task Status | XP Earned | Conditions |
|-------------|-----------|------------|
| **Completed (On-time)** | 20 XP | Completed before 2 AM deadline |
| **Logged (Not necessary/Didn't do)** | 10 XP | Marked as not applicable |
| **Late Completion** | 0 XP | Completed after 2 AM deadline |
| **Skipped/Incomplete** | 0 XP | No action taken |

### Overflow Calculation

```javascript
function calculateRealXP(rawXP) {
  const baseLimit = 200;
  const overflowRate = 0.25;

  if (rawXP <= baseLimit) {
    return rawXP;
  }

  const overflow = (rawXP - baseLimit) * overflowRate;
  return baseLimit + overflow;
}

// Examples:
calculateRealXP(150);  // = 150 (under limit)
calculateRealXP(200);  // = 200 (at limit)
calculateRealXP(240);  // = 210 (200 + 40*0.25)
calculateRealXP(400);  // = 250 (200 + 200*0.25, capped)
```

## 🏆 Level System

### Level Formula

```
Level = floor(sqrt(Total_XP / 100)) + 1
```

### XP Required for Levels

| Level | XP Required | XP Difference |
|-------|-------------|---------------|
| 1 | 0 | - |
| 2 | 100 | 100 |
| 3 | 400 | 300 |
| 4 | 900 | 500 |
| 5 | 1,600 | 700 |
| 10 | 8,100 | - |
| 20 | 36,100 | - |

### Level Rewards

Each level grants **Diamond** rewards:
- **Diamonds per level**: `level * 10`
- **Example**: Level 5 = 50 Diamonds

## 💰 Economic Integration

### Triple Currency System

1. **XP**: Progression and level advancement
2. **Coins**: Task completion rewards (immediate gratification)
3. **Diamonds**: Level-up rewards (long-term achievements)

### XP-Coin Relationship

```javascript
// Coin rewards based on XP earning
function calculateCoins(taskStatus, taskDifficulty = 1) {
  switch (taskStatus) {
    case 'completed':
      return 10 * taskDifficulty;  // + 20 XP
    case 'logged':
      return 5 * taskDifficulty;   // + 10 XP
    case 'late':
      return 3 * taskDifficulty;   // + 0 XP
    default:
      return 0;                    // + 0 XP
  }
}
```

## 🔄 Gap Period UI Behavior

### Display Logic

During 0-2 AM, the UI shows dual XP limits to help users understand the system:

```
Today: 180/200 XP (+ 35/50 overflow)
Tomorrow: 40/200 XP (+ 0/50 overflow)
```

### Tooltip Content

**Regular hours (2 AM - Midnight):**
```
"Daily XP: 180/200 (+25% overflow available)"
```

**Gap period (Midnight - 2 AM):**
```
"Today: 180/200 XP (tasks from yesterday's date)
Tomorrow: 40/200 XP (tasks from today's date)
Daily reset in 47 minutes"
```

## 🎨 Visual Indicators

### Progress Display

1. **Circular Progress Ring**: Shows current level progress
2. **XP Bar**: Daily XP progress with overflow section
3. **Level Badge**: Current level with next level preview
4. **Streak Counter**: Consecutive days of meaningful XP earning

### Color Coding

- **Green**: On track (>80% of daily limit)
- **Yellow**: Moderate progress (40-80% of daily limit)
- **Red**: Low progress (<40% of daily limit)
- **Blue**: Overflow XP (above 200)
- **Purple**: Level-up available

## 🔧 Implementation Details

### Database Schema

```sql
-- User XP tracking
CREATE TABLE user_xp (
  user_id UUID PRIMARY KEY,
  base_xp INTEGER DEFAULT 0,
  today_xp INTEGER DEFAULT 0,
  tomorrow_xp INTEGER DEFAULT 0,
  last_reset_date DATE DEFAULT CURRENT_DATE,
  current_level INTEGER DEFAULT 1,
  total_diamonds INTEGER DEFAULT 0,
  CONSTRAINT positive_xp CHECK (
    base_xp >= 0 AND
    today_xp >= 0 AND
    tomorrow_xp >= 0
  )
);

-- XP transaction log
CREATE TABLE xp_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  task_id UUID REFERENCES tasks(id),
  xp_earned INTEGER,
  transaction_type VARCHAR(20), -- 'earned', 'reset', 'correction'
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Service Implementation

```dart
class XPService {
  // Calculate real XP with overflow
  static int calculateRealXP(int rawXP) {
    const baseLimit = 200;
    const overflowRate = 0.25;

    if (rawXP <= baseLimit) return rawXP;

    final overflow = ((rawXP - baseLimit) * overflowRate).floor();
    final maxOverflow = (baseLimit * overflowRate).floor();

    return baseLimit + math.min(overflow, maxOverflow);
  }

  // Determine which XP bucket to use during gap period
  static String getXPBucket(DateTime taskDate, DateTime completionTime) {
    final isGapPeriod = completionTime.hour < 2;
    if (!isGapPeriod) return 'today';

    final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
    final completionDay = DateTime(completionTime.year, completionTime.month, completionTime.day);

    return taskDay.isBefore(completionDay) ? 'today' : 'tomorrow';
  }

  // Daily reset logic
  static Future<void> performDailyReset(String userId) async {
    final user = await getUserXP(userId);

    final newBaseXP = user.baseXP + calculateRealXP(user.todayXP);
    final newLevel = calculateLevel(newBaseXP + calculateRealXP(user.tomorrowXP));

    await updateUserXP(userId, {
      'base_xp': newBaseXP,
      'today_xp': user.tomorrowXP,
      'tomorrow_xp': 0,
      'current_level': newLevel,
      'last_reset_date': DateTime.now().toIso8601String(),
    });

    // Award diamonds if level increased
    if (newLevel > user.currentLevel) {
      await awardLevelUpRewards(userId, newLevel, user.currentLevel);
    }
  }
}
```

## 📈 Analytics & Insights

### Key Metrics

1. **Daily XP Distribution**: Track how users earn XP throughout the day
2. **Overflow Usage**: Monitor how often users exceed daily limits
3. **Gap Period Behavior**: Analyze late-night completion patterns
4. **Level Progression**: Average time to reach different levels
5. **Dropout Points**: Where users stop engaging with the system

### Performance Optimization

1. **Cached Calculations**: Store calculated values to avoid repeated computation
2. **Batch Processing**: Group XP updates for efficiency
3. **Index Strategy**: Optimize database queries for XP lookups
4. **Background Jobs**: Handle daily resets asynchronously

## 🧪 Testing Scenarios

### Unit Tests

```dart
group('XP Calculation', () {
  test('should cap XP at 200 + 25% overflow', () {
    expect(XPService.calculateRealXP(300), equals(250));
  });

  test('should handle gap period bucket assignment', () {
    final taskDate = DateTime(2024, 3, 14);
    final completionTime = DateTime(2024, 3, 15, 1, 30); // 1:30 AM

    expect(XPService.getXPBucket(taskDate, completionTime), equals('today'));
  });
});
```

### Integration Tests

1. **Daily Reset**: Verify proper XP transfer and level calculation
2. **Gap Period**: Test task completion during midnight-2AM window
3. **Level Up**: Ensure diamond rewards are correctly awarded
4. **Concurrent Updates**: Handle simultaneous XP updates safely

## 🚨 Edge Cases & Error Handling

### Common Edge Cases

1. **Clock Changes**: Handle daylight saving time transitions
2. **Rapid Completion**: Multiple tasks completed simultaneously
3. **Data Corruption**: Invalid XP values in database
4. **Network Issues**: Offline XP accumulation and sync
5. **Time Zone Shifts**: User traveling across time zones

### Error Recovery

```dart
class XPErrorHandler {
  static Future<void> validateAndCorrectXP(String userId) async {
    final user = await getUserXP(userId);

    // Validate XP values
    if (user.todayXP < 0 || user.tomorrowXP < 0) {
      await logXPError(userId, 'Negative XP detected');
      await resetDailyXP(userId);
    }

    // Check for missed daily resets
    if (shouldHaveReset(user.lastResetDate)) {
      await performEmergencyReset(userId);
    }
  }
}
```

## 📝 Future Enhancements

### Planned Features

1. **Dynamic XP Rewards**: Adjust XP based on task difficulty and user behavior
2. **Streak Multipliers**: Bonus XP for consecutive days
3. **Social Features**: XP leaderboards and friend comparisons
4. **Seasonal Events**: Special XP bonuses during events
5. **Achievement System**: XP-based achievements and milestones

### Performance Improvements

1. **Real-time Updates**: WebSocket-based XP updates
2. **Predictive Loading**: Preload next level requirements
3. **Smart Caching**: Context-aware XP data caching
4. **Compression**: Efficient XP history storage

---

## 📚 Additional Resources

- **Implementation**: See `client/lib/services/xp_service.dart`
- **Database Schema**: See `scripts/init.sql`
- **UI Components**: See `client/lib/widgets/xp_widgets/`
- **API Endpoints**: See [API Documentation](api.md)

---

*This document is part of the Apogee technical documentation. For questions or clarifications, please refer to the [Contributing Guide](../CONTRIBUTING.md).*