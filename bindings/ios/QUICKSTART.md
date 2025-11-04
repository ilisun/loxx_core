# ⚡️ LoxxRouter — Быстрый старт (5 минут)

Минимальная интеграция LoxxRouter в iOS проект.

## 1️⃣ Добавьте пакет (30 сек)

В Xcode: **File → Add Package Dependencies**

```
https://github.com/your-username/LoxxCore.git
```

## 2️⃣ Добавьте базу данных (1 мин)

1. Скачайте `.routingdb` для вашего региона
2. Drag & drop в Xcode
3. Отметьте галочкой ваш Target

## 3️⃣ Напишите код (3 мин)

### SwiftUI (iOS 15+)

```swift
import SwiftUI
import LoxxRouter
import CoreLocation

struct ContentView: View {
    @State private var route: LoxxRoute?
    let router = try! LoxxRouter.bundled()
    
    var body: some View {
        VStack {
            if let route {
                Text("📍 \(route.distanceFormatted)")
                Text("⏱️ \(route.durationFormatted)")
            }
            
            Button("Построить маршрут") {
                Task {
                    let start = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
                    let end = CLLocationCoordinate2D(latitude: 55.7522, longitude: 37.6156)
                    route = try? await router.calculateRoute(from: start, to: end)
                }
            }
        }
    }
}
```

### UIKit

```swift
import UIKit
import LoxxRouter

class ViewController: UIViewController {
    let router = try! LoxxRouter.bundled()
    
    @IBAction func buildRoute() {
        let start = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let end = CLLocationCoordinate2D(latitude: 55.7522, longitude: 37.6156)
        
        router.calculateRoute(from: start, to: end) { result in
            if case .success(let route) = result {
                print("✅ Маршрут: \(route.distanceFormatted)")
            }
        }
    }
}
```

## 🎉 Готово!

Полная документация: [README.md](README.md)

