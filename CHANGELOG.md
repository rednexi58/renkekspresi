# Değişiklik günlüğü

## 0.41.0 — Milestone 1: Stabilite ve Apple uyumu

- Oyun artık tamamen çevrimdışı oynanıyor. Bölüm başında ve uygulamaya dönüşte yapılan zorunlu internet kontrolü kaldırıldı; WebGL `online.txt` üretimi silindi.
- Kurgusal isimli örnek "Sıralama" ekranı kaldırıldı, yerine bu cihazdaki gerçek ilerlemeyi gösteren **Rekorlarım** ekranı geldi.
- `ICommerce` arayüzüne `StoreSupported` / `AdsSupported` yetenekleri eklendi. Gerçek mağaza veya reklam sağlayıcısı yokken VIP butonu, kilitli VIP/Reklam yuvaları, 3D istasyondaki kullanılamayan peronlar ve "Reklam izle" akışları gösterilmiyor.
- Booster hakkı bitince ölü bir reklam penceresi yerine "Tükendi" bilgisi gösteriliyor.
- İlk açılışta arayüz dili cihaz diline göre seçiliyor (Türkçe cihaz → TR, diğerleri → EN). Oyuncunun seçtiği dil her zaman korunur.
- Satın alımları geri yükleme dönüşü bölüm değiştiyse yok sayılıyor (eski callback koruması).
- Toplayıcı istasyona uçarken istasyonda aynı anda ikinci bir kopyasının görünmesi düzeltildi.
- iOS Info.plist: `ITSAppUsesNonExemptEncryption = false` ve `UIRequiresFullScreen = true` otomatik yazılıyor.
- Verification: yeni dil ve sağlayıcı-yeteneği kontrolleri eklendi.

Bu değişiklikler Unity Editor olmayan bir ortamda yazıldı; Unity derlemesi ve cihaz testi henüz yapılmadı.
