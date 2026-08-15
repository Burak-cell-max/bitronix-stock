# Bitronix Stock

Tek Flutter kod tabanı ile Windows yönetim uygulaması ve Android/iOS operasyon uygulaması.

Yönetim paneli bir web sitesi değil; Windows için derlenen, modern SaaS dashboard estetiğine sahip yerel bir masaüstü uygulamasıdır. Üretim paketi `flutter build windows --release` ile oluşturulur.

## Firebase bağlantısı

1. Firebase CLI ile bir proje oluşturun ve Authentication (E-posta/Şifre), Firestore ve Storage'ı etkinleştirin.
2. Proje kökünde `flutterfire configure` çalıştırın.
3. `lib/main.dart` içinde `firebase_options.dart` dosyasını içe aktarıp `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` kullanın.
4. `firebase deploy --only firestore:rules,firestore:indexes` ile kuralları yayınlayın.

Android barkod taraması için kamera izni manifest'e eklenmiştir. iOS için `ios/Runner/Info.plist` dosyasına `NSCameraUsageDescription` ekleyin.

`products` belgeleri için temel alanlar: `name`, `sku`, `barcode`, `currentStock`, `minimumStock`, `criticalStock`, `unit`, `warehouseId`, `isDeleted`.

Stok hareketleri Firestore transaction'ı ile ürün stok değerini ve silinemez `stock_movements` kaydını birlikte oluşturur. Üretimde bu çağrıların Cloud Functions üzerinden yapılması önerilir; böylece istemci doğrudan stok güncelleme yetkisi taşımaz.
