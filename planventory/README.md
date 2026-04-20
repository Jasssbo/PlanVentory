# PlanVentory

An inventory and calendar app for event services to track events and materials.

---

## 🚀 Quick Start

```bash
cd planventory
flutter run -d linux    # Linux desktop
flutter run -d chrome   # Web browser
flutter run -d android  # Android device/emulator
```

---

## 📁 Where to Customize Things

### 🎨 Colors & Theme

**File:** `lib/theme/app_colors.dart`

Change the app's colors here:
```dart
static const Color primary = Color(0xFF6366F1);       // Main app color (Indigo)
static const Color secondary = Color(0xFF10B981);     // Accent color (Emerald)
static const Color success = Color(0xFF22C55E);       // Success messages
static const Color warning = Color(0xFFF59E0B);       // Warnings
static const Color error = Color(0xFFEF4444);         // Errors
```

**Tip:** Use a color picker tool and replace the hex values (e.g., `0xFF6366F1` → `0xFF3B82F6` for blue).

---

### 📝 App Name & Info

**File:** `lib/config/app_config.dart`

```dart
static const String appName = 'PlanVentory';    // Change app display name
static const String appVersion = '1.0.0';        // Update version
```

**File:** `pubspec.yaml` (line 1)
```yaml
name: planventory    # Package name (lowercase, no spaces)
description: "Your description here"
```

---

### 🗂️ Default Categories for Items

**File:** `lib/utils/constants.dart`

```dart
static const List<String> defaultCategories = [
  'Audio',
  'Lighting',
  'Furniture',
  'Decoration',
  'Catering',
  'Electronics',
  'Textiles',
  'Other',
];
```

Add, remove, or rename categories to match your business.

---

### 📱 Screens (Pages)

All screens are in `lib/screens/`:

| File | What it shows |
|------|---------------|
| `home_screen.dart` | Dashboard with stats and overview |
| `calendar_screen.dart` | Monthly calendar view |
| `events_screen.dart` | List of all events |
| `inventory_screen.dart` | List of all items |
| `event_detail_screen.dart` | Single event details |

---

### 🧩 Reusable Components (Widgets)

All widgets are in `lib/widgets/`:

| File | What it is |
|------|------------|
| `event_card.dart` | Card showing event summary |
| `item_tile.dart` | Row showing inventory item |
| `warning_banner.dart` | Alert banner for conflicts |

---

### 📊 Data Models

What data is stored (in `lib/models/`):

| File | Fields |
|------|--------|
| `item.dart` | name, description, quantity, category |
| `event.dart` | name, description, location, start/end date, status |
| `allocation.dart` | Links items to events with quantity needed |
| `warning.dart` | Inventory conflict warnings |

---

### 🗄️ Database

**File:** `lib/services/database/database_service.dart`

The SQLite database tables are created here. If you need to add a new field:
1. Add it to the model in `lib/models/`
2. Add it to the `CREATE TABLE` statement
3. Update `toMap()` and `fromMap()` methods in the model

---

### 🔀 Navigation

**Routes:** `lib/routes/app_routes.dart`
```dart
static const String home = '/';
static const String calendar = '/calendar';
static const String inventory = '/inventory';
```

**Bottom navigation tabs:** `lib/screens/main_shell.dart`

---

## 🛠️ Common Customizations

### Change the primary color to blue:
Edit `lib/theme/app_colors.dart`:
```dart
static const Color primary = Color(0xFF3B82F6);  // Blue
```

### Add a new item field (e.g., "price"):
1. Edit `lib/models/item.dart` - add `final double? price;`
2. Update `toMap()`, `fromMap()`, and `copyWith()`
3. Edit `lib/services/database/database_service.dart` - add column
4. Edit `lib/screens/inventory_screen.dart` - add form field

### Change the app icon:
Replace images in:
- `android/app/src/main/res/` (Android)
- `ios/Runner/Assets.xcassets/` (iOS)
- `web/icons/` (Web)
- `linux/` (Linux)

Or use: `flutter pub add flutter_launcher_icons`

---

## 📂 Full Structure

```
lib/
├── main.dart              # App entry point
├── config/                # Settings & environment
├── core/                  # Base classes & utilities
├── extensions/            # Dart helper extensions
├── models/                # Data structures
├── providers/             # State management
├── routes/                # Navigation
├── screens/               # Full pages
├── services/              # Business logic & database
├── theme/                 # Colors & styling
├── utils/                 # Constants & helpers
└── widgets/               # Reusable UI components
```

---

## 🆘 Need Help?

- **Flutter docs:** https://docs.flutter.dev
- **Dart language:** https://dart.dev/guides
- **Material Design:** https://m3.material.io

---

Made with ❤️ for event service professionals
