# LoxxCore Mobile Bindings

Нативные SDK для мобильных платформ на основе C++ ядра LoxxCore.

## 📱 Доступные платформы

### ✅ iOS (Ready)

**Статус:** Готово к использованию  
**Язык:** Pure Swift API  
**Минимальная версия:** iOS 13.0+  
**Документация:** [bindings/ios/README.md](ios/README.md)

**Возможности:**
- ✅ Чистый Swift API с CoreLocation
- ✅ Async/await support (iOS 15+)
- ✅ MapLibre интеграция
- ✅ Swift Package Manager
- ✅ Полная документация
- ✅ Пример SwiftUI приложения
- ✅ Unit тесты

**Быстрый старт:**
```swift
import LoxxRouter

let router = try LoxxRouter.bundled()
let route = try await router.calculateRoute(from: start, to: end, profile: .car)
print("Маршрут: \(route.distanceFormatted) за \(route.durationFormatted)")
```

---

### 🚧 Android (Planned)

**Статус:** В разработке (Iteration 1, следующий этап)  
**Язык:** Kotlin + JNI  
**Минимальная версия:** Android 5.0+ (API 21)  
**Формат:** `.aar` библиотека

**Планируемые возможности:**
- [ ] Kotlin-first API
- [ ] Coroutines support
- [ ] MapLibre integration
- [ ] Gradle/Maven distribution
- [ ] Jetpack Compose example
- [ ] JUnit tests

**Планируемый API:**
```kotlin
val router = LoxxRouter.bundled(context, "moscow/routing")
val route = router.calculateRoute(start, end, RoutingProfile.CAR)
println("Route: ${route.distance} in ${route.duration}")
```

---

## 🏗️ Архитектура

```
Mobile App (Swift/Kotlin)
       ↓
Pure Swift/Kotlin Public API
       ↓
Thin Bridge (Objective-C++ / JNI)
       ↓
C++20 Core (routing_core)
       ↓
SQLite + FlatBuffers Data
```

### Принципы дизайна

1. **Native-first API** — идиоматичный код для каждой платформы
2. **Минимальные зависимости** — только CoreLocation/Android Location
3. **Zero-copy** — FlatBuffers для быстрого доступа к данным
4. **Thread-safe** — безопасная работа из любого потока
5. **Async-friendly** — поддержка современных паттернов concurrency

## 📊 Сравнение платформ

| Функция | iOS | Android | 
|---------|-----|---------|
| Pure API | ✅ Swift | 🚧 Kotlin |
| Async/await | ✅ | 🚧 Coroutines |
| MapLibre | ✅ | 🚧 |
| Package Manager | ✅ SPM | 🚧 Maven |
| Documentation | ✅ | 🚧 |
| Example App | ✅ SwiftUI | 🚧 Compose |
| Tests | ✅ XCTest | 🚧 JUnit |

## 🚀 Использование

### iOS

```bash
cd bindings/ios
open Package.swift
```

См. [iOS README](ios/README.md) и [Quick Start](ios/QUICKSTART.md)

### Android (Coming soon)

```bash
cd bindings/android
./gradlew build
```

## 📦 Структура репозитория

```
bindings/
├── README.md              # Этот файл
├── ios/                   # iOS SDK
│   ├── Package.swift      # Swift Package
│   ├── README.md          # Полная документация
│   ├── QUICKSTART.md      # Быстрый старт
│   ├── INTEGRATION_GUIDE.md  # Руководство по интеграции
│   ├── Sources/
│   │   ├── LoxxRouter/              # Public Swift API
│   │   │   ├── LoxxRouter.swift
│   │   │   ├── MapLibreIntegration.swift
│   │   │   └── LoxxRouterBridge+Swift.swift
│   │   └── LoxxRouterCore/          # Private C++ bridge
│   │       ├── include/
│   │       │   └── LoxxRouterBridge.h
│   │       └── LoxxRouterBridge.mm
│   ├── Tests/
│   │   └── LoxxRouterTests/         # Unit tests
│   └── Examples/
│       └── LoxxRouterDemo/          # SwiftUI demo app
└── android/               # Android SDK (TBD)
    ├── build.gradle
    ├── README.md
    └── ...
```

## 🔧 Сборка

### iOS

Требования:
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+

```bash
cd bindings/ios
swift build
swift test
```

### Android (TBD)

Требования:
- Android Studio Arctic Fox+
- Gradle 8.0+
- NDK r25+

```bash
cd bindings/android
./gradlew assembleRelease
./gradlew test
```

## 📚 Документация

- **iOS:** [ios/README.md](ios/README.md)
- **Core C++ API:** [../core/include/routing_core/](../core/include/routing_core/)
- **Спецификация:** [../docs/main_spec.md](../docs/main_spec.md)
- **План разработки:** [../docs/plan.md](../docs/plan.md)

## 🎯 Roadmap

### iOS ✅ v1.0 (Complete)
- [x] Pure Swift API
- [x] Async/await support
- [x] MapLibre integration
- [x] Full documentation
- [x] Example app
- [x] Unit tests

### Android 🚧 v1.0 (Next)
- [ ] Kotlin API
- [ ] Coroutines support
- [ ] MapLibre integration
- [ ] Documentation
- [ ] Example app
- [ ] Unit tests

### Future
- [ ] React Native bindings
- [ ] Flutter plugin
- [ ] Xamarin/MAUI bindings

## 💡 Вклад в разработку

См. [CONTRIBUTING.md](../CONTRIBUTING.md)

## 📄 Лицензия

MIT License — см. [LICENSE](../LICENSE)

Данные карт: © OpenStreetMap contributors (ODbL)

