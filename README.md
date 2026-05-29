# PantryPal 🥦

> Scan grocery receipts → track expiry dates → get alerts before food goes to waste → see what to cook tonight.

---

## Features

- **📷 Receipt Scanner** — OCR reads grocery receipts, auto-detects food items
- **🥗 Smart Pantry** — fridge, freezer, pantry organised in one place
- **⏰ Expiry Alerts** — notifications before food expires (1 day warning)
- **📊 Waste Dashboard** — see consumed vs wasted, money lost to waste
- **🛒 Shopping List** — running list of what you need
- **🌙 Dark Mode** — full system dark/light support
- **🔒 Offline-First** — all data local, no account needed

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.10+ |
| Language | Dart 3.0+ |
| State | BLoC pattern |
| OCR | Google ML Kit |
| Database | SQLite (sqflite) |
| Notifications | flutter_local_notifications |
| Charts | fl_chart |
| DI | GetIt |
| Architecture | Clean Architecture |

---

## Setup Instructions

### Prerequisites
```bash
flutter --version  # needs Flutter 3.10+
```

### 1. Install fonts (important)

Download **Nunito** from https://fonts.google.com/specimen/Nunito and place these files in `assets/fonts/`:
- `Nunito-Regular.ttf`
- `Nunito-SemiBold.ttf`
- `Nunito-Bold.ttf`
- `Nunito-ExtraBold.ttf`

> Without fonts the app still runs with system font fallback.

### 2. Get dependencies
```bash
cd pantrypal
flutter pub get
```

### 3. Android setup

In `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### 4. iOS setup
```bash
cd ios && pod install && cd ..
```
Min iOS: 12.0

### 5. Run
```bash
flutter run
# or release builds:
flutter build apk --release
flutter build ios --release
```

---

## Project Structure

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # Root widget + theme
├── injection_container.dart           # GetIt DI
├── core/
│   ├── constants/app_constants.dart   # Shelf life defaults, keywords
│   ├── theme/app_theme.dart           # Colors + ThemeData
│   └── utils/
│       ├── database_helper.dart       # SQLite CRUD
│       └── grocery_ocr_parser.dart    # OCR → food items
├── features/
│   ├── dashboard/                     # Home dashboard
│   ├── pantry/
│   │   ├── domain/entities/           # PantryItem, ShoppingItem
│   │   ├── data/repositories/         # PantryRepository
│   │   └── presentation/
│   │       ├── bloc/pantry_bloc.dart  # State management
│   │       ├── pages/                 # PantryPage, ShoppingPage
│   │       └── widgets/               # Cards, dialogs
│   └── scan/
│       ├── data/scan_bloc.dart        # OCR + state
│       └── presentation/pages/        # Camera + review pages
└── shared/
    ├── services/notification_service.dart
    └── widgets/                       # Shared UI
```

---

## App Store Readiness

| Check | Status |
|-------|--------|
| Camera usage description | ✅ |
| Photo library description | ✅ |
| ATS configured | ✅ |
| Offline-first (no network required) | ✅ |
| No hardcoded API keys | ✅ |
| Dark mode support | ✅ |
| Accessibility (semantic labels) | ⚠ Partial |
| Privacy policy needed | ⚠ For submission |

---

## Monetization Roadmap

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | 20 items, basic expiry tracking |
| Fresh Pro | $2.99/mo | Unlimited items, recipe suggestions, waste reports |
| Family | $4.99/mo | 5 accounts, shared pantry |

---

## Upcoming Features (v2)

- [ ] Recipe suggestions from expiring items (AI-powered)
- [ ] Barcode scanner for individual items
- [ ] Cloud sync across devices
- [ ] Meal planning calendar
- [ ] Weekly waste report email
- [ ] Smart shopping list auto-generation
- [ ] Family sharing mode

---

Built with Flutter · Zero food waste starts at home.
