# LoxxRouter для iOS

Быстрая оффлайн-маршрутизация для iOS приложений на основе данных OpenStreetMap.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2013.0+-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 Содержание

- [Возможности](#возможности)
- [Требования](#требования)
- [Установка](#установка)
- [Быстрый старт](#быстрый-старт)
- [Интеграция с MapLibre](#интеграция-с-maplibre)
- [Примеры использования](#примеры-использования)
- [API Reference](#api-reference)
- [Производительность](#производительность)
- [FAQ](#faq)

## ✨ Возможности

- 🚗 **Автомобильная маршрутизация** — учёт односторонних дорог, классов дорог
- 🚶 **Пешеходная маршрутизация** — пешеходные дорожки, тротуары, парки
- 📱 **100% оффлайн** — работает без интернета
- ⚡️ **Быстро** — маршруты до 50 км за < 300 мс
- 🗺️ **MapLibre интеграция** — готовые расширения для отображения маршрутов
- 🔄 **Async/await** — современный Swift concurrency API (iOS 15+)
- 📦 **Лёгкая интеграция** — Swift Package Manager
- 🎯 **Типобезопасность** — чистый Swift API с CoreLocation

## 📱 Требования

- iOS 13.0+
- macOS Catalyst 13.0+
- Xcode 15.0+
- Swift 5.9+

## 📦 Установка

### Swift Package Manager

1. В Xcode: **File → Add Package Dependencies...**
2. Вставьте URL репозитория:
```
https://github.com/your-username/LoxxCore.git
```
3. Выберите версию и добавьте в проект

Или добавьте в `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/LoxxCore.git", from: "1.0.0")
]
```

### Подготовка данных

1. **Скачайте оффлайн-пакет** для нужного региона (`.routingdb` файл)
2. **Добавьте в проект:**
   - Drag & drop файл в Xcode
   - Убедитесь, что он добавлен в **Target → Build Phases → Copy Bundle Resources**

## 🚀 Быстрый старт

### 1. Инициализация роутера

```swift
import LoxxRouter
import CoreLocation

// Из Bundle (встроенный файл)
let router = try LoxxRouter.bundled(resourceName: "arkhangelsk/routing")

// Из Documents directory (загруженный файл)
let router = try LoxxRouter.documents(filename: "moscow.routingdb")

// С кастомными настройками
var options = LoxxRouterOptions()
options.tileCacheCapacity = 256 // больше кэш для быстрых повторных запросов
let router = try LoxxRouter(databasePath: path, options: options)
```

### 2. Расчёт маршрута (iOS 15+, async/await)

```swift
let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)

do {
    let route = try await router.calculateRoute(
        from: start,
        to: end,
        profile: .car
    )
    
    print("Расстояние: \(route.distanceFormatted)")  // "11.3 km"
    print("Время: \(route.durationFormatted)")       // "5 min"
    print("Скорость: \(route.averageSpeed) км/ч")   // 38.0
    
} catch let error as LoxxRouterError {
    switch error {
    case .noRoute:
        print("Маршрут не найден")
    case .noTileData:
        print("Нет данных для этого региона")
    default:
        print("Ошибка: \(error.localizedDescription)")
    }
}
```

### 3. Completion handler (iOS 13+)

```swift
router.calculateRoute(from: start, to: end, profile: .foot) { result in
    switch result {
    case .success(let route):
        print("Найден маршрут: \(route.distanceFormatted)")
        self.displayRoute(route)
        
    case .failure(let error):
        print("Ошибка: \(error.localizedDescription)")
    }
}
```

## 🗺️ Интеграция с MapLibre

### Установка MapLibre

Добавьте MapLibre Native в проект:

```swift
dependencies: [
    .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.0.0")
]
```

### Отображение маршрута

```swift
import MapLibre
import LoxxRouter

class MapViewController: UIViewController {
    let mapView = MLNMapView()
    let router = try! LoxxRouter.bundled()
    
    func showRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async {
        do {
            // 1. Рассчитать маршрут
            let route = try await router.calculateRoute(from: start, to: end, profile: .car)
            
            // 2. Добавить на карту
            guard let style = mapView.style else { return }
            route.addToMapStyle(style, color: .systemBlue, width: 5)
            
            // 3. Приблизить камеру к маршруту
            mapView.showRoute(route, edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50))
            
            // 4. Показать информацию
            showRouteInfo(route)
            
        } catch {
            showError(error)
        }
    }
}
```

### Стилизация маршрута

```swift
// Простой стиль
route.addToMapStyle(style, identifier: "my-route", color: .systemBlue, width: 5)

// С обводкой (casing)
route.addToMapStyleWithCasing(
    style,
    lineColor: .systemBlue,
    lineWidth: 5,
    casingColor: .white,
    casingWidth: 7
)

// Добавить слой под существующий
route.addToMapStyle(style, belowLayerIdentifier: "road-label")
```

## 📖 Примеры использования

### SwiftUI + MapLibre

```swift
import SwiftUI
import MapLibre
import LoxxRouter

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    
    var body: some View {
        ZStack {
            MapLibreView(route: $viewModel.route)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                if let route = viewModel.route {
                    RouteCard(route: route)
                        .padding()
                }
                
                Button("Построить маршрут") {
                    Task {
                        await viewModel.buildRoute()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
}

@MainActor
class MapViewModel: ObservableObject {
    @Published var route: LoxxRoute?
    private lazy var router = try? LoxxRouter.bundled()
    
    func buildRoute() async {
        let start = CLLocationCoordinate2D(latitude: 64.589700, longitude: 40.507520)
        let end = CLLocationCoordinate2D(latitude: 64.541891, longitude: 40.539648)
        
        do {
            route = try await router?.calculateRoute(from: start, to: end, profile: .car)
        } catch {
            print("Ошибка маршрутизации: \(error)")
        }
    }
}

struct RouteCard: View {
    let route: LoxxRoute
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(route.distanceFormatted)
                    .font(.headline)
                Text(route.durationFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}
```

### Работа с текущим местоположением

```swift
import CoreLocation

class LocationRouter: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    let router = try! LoxxRouter.bundled()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func routeToDestination(_ destination: CLLocationCoordinate2D) async throws -> LoxxRoute {
        guard let currentLocation = locationManager.location else {
            throw LoxxRouterError.internalError("Location not available")
        }
        
        return try await router.calculateRoute(
            from: currentLocation,
            to: destination,
            profile: .foot
        )
    }
}
```

### Загрузка оффлайн-пакетов

```swift
class RegionManager {
    func downloadRegion(named: String) async throws -> URL {
        let url = URL(string: "https://your-server.com/packages/\(named).routingdb")!
        
        // Скачать файл
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        
        // Переместить в Documents
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent("\(named).routingdb")
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    func routerForRegion(named: String) throws -> LoxxRouter {
        try LoxxRouter.documents(filename: "\(named).routingdb")
    }
}

// Использование
let manager = RegionManager()

// Скачать регион
let url = try await manager.downloadRegion(named: "moscow")

// Использовать роутер
let router = try manager.routerForRegion(named: "moscow")
```

## 📚 API Reference

### LoxxRouter

Главный класс для расчёта маршрутов.

#### Инициализация

```swift
// Основной инициализатор
init(databasePath: String, options: LoxxRouterOptions = LoxxRouterOptions()) throws

// Convenience initializers
static func bundled(resourceName: String = "routing", 
                   bundle: Bundle = .main, 
                   options: LoxxRouterOptions = LoxxRouterOptions()) throws -> LoxxRouter

static func documents(filename: String, 
                     options: LoxxRouterOptions = LoxxRouterOptions()) throws -> LoxxRouter
```

#### Методы

```swift
// Синхронный расчёт (блокирует поток)
func calculateRoute(from: CLLocationCoordinate2D, 
                   to: CLLocationCoordinate2D, 
                   profile: LoxxRoutingProfile = .car) throws -> LoxxRoute

// Асинхронный с completion handler
func calculateRoute(from: CLLocationCoordinate2D, 
                   to: CLLocationCoordinate2D, 
                   profile: LoxxRoutingProfile = .car,
                   completion: @escaping (Result<LoxxRoute, LoxxRouterError>) -> Void)

// Async/await (iOS 15+)
@available(iOS 15.0, *)
func calculateRoute(from: CLLocationCoordinate2D, 
                   to: CLLocationCoordinate2D, 
                   profile: LoxxRoutingProfile = .car) async throws -> LoxxRoute
```

### LoxxRoute

Результат расчёта маршрута.

```swift
struct LoxxRoute {
    let coordinates: [CLLocationCoordinate2D]  // Полилиния маршрута
    let distance: CLLocationDistance           // Расстояние в метрах
    let duration: TimeInterval                 // Время в секундах
    
    var distanceFormatted: String              // "11.3 km"
    var durationFormatted: String              // "5 min"
    var averageSpeed: Double                   // км/ч
}
```

### LoxxRoutingProfile

Профиль маршрутизации.

```swift
enum LoxxRoutingProfile {
    case car   // Автомобиль: дороги, магистрали
    case foot  // Пешеход: тротуары, пешеходные дорожки
}
```

### LoxxRouterError

Ошибки маршрутизации.

```swift
enum LoxxRouterError: LocalizedError {
    case databaseNotFound    // Файл базы не найден
    case noRoute            // Маршрут не найден
    case noTileData         // Нет данных для региона
    case dataCorrupted      // База данных повреждена
    case internalError(String)  // Внутренняя ошибка
}
```

### LoxxRouterOptions

Настройки роутера.

```swift
struct LoxxRouterOptions {
    var tileZoom: Int = 14              // Уровень тайлов (14 = ~4×4 км)
    var tileCacheCapacity: Int = 128    // Размер кэша тайлов
}
```

## ⚡️ Производительность

### Время расчёта маршрутов

| Расстояние | iPhone 14 Pro | iPhone 12 | iPhone XR |
|-----------|---------------|-----------|-----------|
| 5 км      | ~50 мс        | ~70 мс    | ~100 мс   |
| 20 км     | ~150 мс       | ~220 мс   | ~350 мс   |
| 50 км     | ~300 мс       | ~500 мс   | ~800 мс   |

### Использование памяти

- **Базовое потребление:** ~50 МБ
- **С кэшем 128 тайлов:** ~150-200 МБ
- **База данных региона:** 500 МБ - 1.5 ГБ (не загружается в память целиком)

### Рекомендации по оптимизации

1. **Увеличьте кэш для частых запросов:**
```swift
var options = LoxxRouterOptions()
options.tileCacheCapacity = 256
```

2. **Используйте один экземпляр Router:**
```swift
class AppRouter {
    static let shared = try! LoxxRouter.bundled()
}
```

3. **Вызывайте асинхронно:**
```swift
// ✅ Хорошо
Task {
    let route = try await router.calculateRoute(from: a, to: b)
}

// ❌ Плохо (блокирует UI)
let route = try router.calculateRoute(from: a, to: b)
```

## ❓ FAQ

### Как обновить оффлайн-данные?

Скачайте новый `.routingdb` файл и замените старый. Пересоздайте `LoxxRouter`.

### Сколько весит оффлайн-пакет?

Зависит от региона:
- Небольшой город: 100-300 МБ
- Область/регион: 500-1500 МБ
- Страна: 3-10 ГБ

### Можно ли использовать несколько регионов?

Да, создайте отдельный `LoxxRouter` для каждого региона:

```swift
let moscowRouter = try LoxxRouter.documents(filename: "moscow.routingdb")
let spbRouter = try LoxxRouter.documents(filename: "spb.routingdb")
```

### Работает ли на iPad/Mac Catalyst?

Да, библиотека поддерживает iOS 13+, включая iPad и Mac Catalyst.

### Как добавить свой профиль маршрутизации?

В текущей версии поддерживаются только Car и Foot. Boat и кастомные профили — в будущих версиях.

### Нужен ли интернет?

Нет, библиотека работает 100% оффлайн после загрузки `.routingdb` файла.

## 📄 Лицензия

MIT License. См. [LICENSE](../../LICENSE) для деталей.

Данные карт: © OpenStreetMap contributors, лицензия ODbL.

## 🤝 Поддержка

- 📧 Email: support@loxxrouter.com
- 🐛 Issues: [GitHub Issues](https://github.com/your-username/LoxxCore/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-username/LoxxCore/discussions)

## 🎯 Roadmap

- [ ] Boat профиль (водная маршрутизация)
- [ ] Turn-by-turn навигация
- [ ] Voice guidance
- [ ] Альтернативные маршруты
- [ ] Real-time rerouting
- [ ] Избежание областей
- [ ] Waypoints (промежуточные точки)

