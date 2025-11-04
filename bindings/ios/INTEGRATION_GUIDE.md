# 📱 Руководство по интеграции LoxxRouter в iOS приложение

Пошаговое руководство для iOS разработчиков.

## 📋 Шаг 1: Установка

### Swift Package Manager (рекомендуется)

1. Откройте ваш проект в Xcode
2. **File → Add Package Dependencies...**
3. Введите URL: `https://github.com/your-username/LoxxCore.git`
4. Выберите версию (например, `1.0.0`)
5. Нажмите **Add Package**

## 📦 Шаг 2: Добавление оффлайн-данных

### Вариант A: Встроенная база (Bundle)

1. **Скачайте `.routingdb` файл** для вашего региона
2. **Добавьте в проект:**
   - Drag & drop файл в Xcode
   - Отметьте галочкой ваш Target
   - Убедитесь, что файл в **Target → Build Phases → Copy Bundle Resources**

```
YourApp/
└── Resources/
    └── moscow/
        └── routing.routingdb  [1.2 ГБ]
```

### Вариант B: Загружаемая база (Documents)

Реализуйте загрузку базы из сети:

```swift
class DatabaseManager {
    func downloadDatabase(for region: String) async throws -> URL {
        let url = URL(string: "https://your-cdn.com/\(region).routingdb")!
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, 
            in: .userDomainMask
        )[0]
        let destURL = documentsURL.appendingPathComponent("\(region).routingdb")
        
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        return destURL
    }
}
```

## 🔧 Шаг 3: Базовая интеграция

### Swift + UIKit

```swift
import UIKit
import LoxxRouter
import CoreLocation

class ViewController: UIViewController {
    private lazy var router: LoxxRouter? = {
        try? LoxxRouter.bundled(resourceName: "moscow/routing")
    }()
    
    func calculateRoute() {
        let start = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let end = CLLocationCoordinate2D(latitude: 55.7522, longitude: 37.6156)
        
        router?.calculateRoute(from: start, to: end, profile: .car) { [weak self] result in
            switch result {
            case .success(let route):
                self?.showRoute(route)
            case .failure(let error):
                self?.showError(error.localizedDescription)
            }
        }
    }
    
    private func showRoute(_ route: LoxxRoute) {
        print("Маршрут: \(route.distanceFormatted) за \(route.durationFormatted)")
        // Отобразите на карте...
    }
}
```

### SwiftUI + Async/Await (iOS 15+)

```swift
import SwiftUI
import LoxxRouter

struct RouteView: View {
    @StateObject private var viewModel = RouteViewModel()
    
    var body: some View {
        VStack {
            if let route = viewModel.route {
                Text("Расстояние: \(route.distanceFormatted)")
                Text("Время: \(route.durationFormatted)")
            }
            
            Button("Построить маршрут") {
                Task {
                    await viewModel.buildRoute()
                }
            }
        }
    }
}

@MainActor
class RouteViewModel: ObservableObject {
    @Published var route: LoxxRoute?
    private lazy var router = try? LoxxRouter.bundled()
    
    func buildRoute() async {
        let start = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let end = CLLocationCoordinate2D(latitude: 55.7522, longitude: 37.6156)
        
        do {
            route = try await router?.calculateRoute(from: start, to: end, profile: .car)
        } catch {
            print("Ошибка: \(error)")
        }
    }
}
```

## 🗺️ Шаг 4: Интеграция с MapLibre

### Добавьте MapLibre

```swift
dependencies: [
    .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.0.0")
]
```

### Отображение маршрута

```swift
import MapLibre
import LoxxRouter

extension ViewController {
    private func displayRoute(_ route: LoxxRoute) {
        guard let style = mapView.style else { return }
        
        // Добавить маршрут на карту
        route.addToMapStyle(style, color: .systemBlue, width: 5)
        
        // Приблизить камеру
        mapView.showRoute(route)
    }
}
```

## ⚙️ Шаг 5: Настройка производительности

### Оптимизация кэша

```swift
var options = LoxxRouterOptions()
options.tileCacheCapacity = 256  // Больше кэш = быстрее повторные запросы

let router = try LoxxRouter(databasePath: path, options: options)
```

### Singleton для всего приложения

```swift
class AppRouter {
    static let shared: LoxxRouter = {
        try! LoxxRouter.bundled(resourceName: "moscow/routing")
    }()
}

// Использование
let route = try await AppRouter.shared.calculateRoute(from: a, to: b)
```

## 🚨 Шаг 6: Обработка ошибок

```swift
do {
    let route = try await router.calculateRoute(from: start, to: end)
    // Успех
} catch let error as LoxxRouterError {
    switch error {
    case .databaseNotFound:
        showAlert("База данных не найдена. Скачайте оффлайн-пакет.")
    case .noRoute:
        showAlert("Маршрут не найден между указанными точками.")
    case .noTileData:
        showAlert("Нет данных для этого региона.")
    case .dataCorrupted:
        showAlert("База данных повреждена. Переустановите приложение.")
    case .internalError(let message):
        showAlert("Ошибка: \(message)")
    }
}
```

## 🎯 Шаг 7: Работа с текущим местоположением

```swift
import CoreLocation

class LocationRouterManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let router = try! LoxxRouter.bundled()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func routeToDestination(_ destination: CLLocationCoordinate2D) async throws -> LoxxRoute {
        guard let location = locationManager.location else {
            throw NSError(domain: "Location", code: 1)
        }
        
        return try await router.calculateRoute(
            from: location.coordinate,
            to: destination,
            profile: .car
        )
    }
}
```

## 📲 Шаг 8: Добавьте разрешения в Info.plist

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Нужно для построения маршрута от вашего местоположения</string>
```

## ✅ Чек-лист интеграции

- [ ] Установлен Swift Package
- [ ] Добавлен `.routingdb` файл в проект
- [ ] Реализована инициализация Router
- [ ] Реализован расчёт маршрута
- [ ] Добавлена обработка ошибок
- [ ] Интегрирована MapLibre (опционально)
- [ ] Добавлены разрешения локации
- [ ] Протестирована производительность
- [ ] Проверена работа на реальном устройстве

## 🎓 Полезные ресурсы

- [Полная документация API](README.md)
- [Пример SwiftUI приложения](Examples/README.md)
- [Unit тесты](Tests/LoxxRouterTests/)

## 💡 Советы

1. **Кэшируйте Router instance** — создание нового Router каждый раз медленно
2. **Используйте async/await** — не блокируйте main thread
3. **Тестируйте на реальных устройствах** — симулятор может быть быстрее
4. **Мониторьте память** — большая база может занимать много RAM при активном использовании

## 🐛 Troubleshooting

### "Database not found"
- Проверьте, что файл добавлен в Copy Bundle Resources
- Проверьте правильность имени файла

### Медленный расчёт маршрута
- Увеличьте `tileCacheCapacity`
- Убедитесь, что используете async вызовы
- Проверьте, что база на внутреннем хранилище (не на iCloud)

### "No tile data"
- Координаты вне региона базы данных
- Используйте координаты из вашего региона

## 📞 Поддержка

Если возникли вопросы:
- 📧 Email: support@loxxrouter.com
- 🐛 GitHub Issues
- 💬 GitHub Discussions

