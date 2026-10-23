# Renk Ekspresi — Unity geçiş paketi 0.40.0

Bu paket, Godot v0.34 kaynaklarından ayrı olarak hazırlanmış **Unity kaynak projesidir**. Godot oyununun yerini henüz almaz. İçinde imzalı IPA, APK veya derlenmiş WebGL yoktur. Unity Editor bu çalışma ortamında bulunmadığı için Unity derlemesi, gerçek ekran görüntüsü ve cihaz performansı doğrulanmamıştır.

Oyun mantığı C# olarak yeniden yazıldı. Orijinal Godot motoru ile aynı hamleler yürütülerek 100 bölüm ve 16 ek senaryoda karşılaştırıldı. Test sonuçları `Verification/TEST_REPORT.md` dosyasındadır. Bu kontroller, Unity import ve cihaz testlerinin yerine geçmez.

## İlk kez açmak

1. ZIP'i tamamen bir klasöre çıkar. `Assets`, `Packages`, `ProjectSettings` klasörlerini birlikte tut.
2. Unity Hub'ı kur ve hesabınla etkinleştir. Proje için **Unity 6000.0.60f1** seç. Bu sürüm proje için sabitlenmiştir; en son Unity sürümü olduğu iddia edilmiyor.
3. Hub → **Projects → Add → Add project from disk** yoluyla bu klasörü seç. Yeni boş proje oluşturma.
4. Paketlerin indirilmesini ve ilk importun bitmesini bekle. İlk açılışta oyun ayarları, düzenlenebilir tren prefabları ve `Main` sahnesi hazırlanır.
5. Sahne açılmazsa üst menüden **Renk Ekspresi → Open game scene** seç.
6. Game penceresinde **9:16** görünüm seçip **Play** düğmesine bas. Oyunun içinden “Devam et” ile başla. İnternet bağlantısı kontrolü vardır.
7. Console'da kırmızı hata varsa hata metnini ve Unity sürümünü paylaş. Bu paket Editor'de çalıştırılmış gibi sunulmamaktadır; ilk import/Play kontrolü gereklidir.

Her bölümü test etmek için Play sırasında **Renk Ekspresi → Level inspector** açılır. Bu araç yalnızca Editor içindedir; oyuncu sürümünde görünmez ve kayıtlı ilerlemeyi açmaz.

## Görsel ve arayüz değişiklikleri

- Sabit ortografik kamera, gerçek 3D tren meshleri, materyal başına metal/parlaklık verisi, yumuşak yönlü ışık ve ortam ışığı.
- Üstte kompakt bölüm/ilerleme paneli; ortada tren ve istasyon; altta ok yönlü toplayıcı bulmacası ve üç yardımcı.
- Krem, koyu petrol ve pirinç renklerinden oluşan ortak arayüz dili; yuvarlatılmış paneller, okunaklı Türkçe/İngilizce yazılar.
- VIP ve bölüm başına ödüllü ek yuva, istasyon yuvalarının yanında görünür.
- Vagon yerleştirme ve eşleşme animasyonları, kısa parıltılar, engelli hamlede küçük hareketli geri bildirim.
- Kıyı, orman, hasat, kasaba, kanyon ve kar çevreleri; bölümün mevcut ray geometrisi korunur.
- Ayrı müzik, tren, efekt ses düzeyleri; titreşim ve düşük grafik seçeneği.

Bunlar kaynakta uygulanmıştır. “Daha iyi görünüyor”, “60 FPS çalışıyor” veya “tüm ekranlarda kusursuz” sonucu için Unity'den alınmış görüntü ve gerçek cihaz ölçümü gerekir. Hedef 60 FPS'tir; ölçülmüş performans değildir.

## Korunan oynanış

- 100 bölümün renkleri, yönleri, kilitleri, kapasiteleri ve çözüm verileri v0.34'ten aktarılmıştır.
- Okun önü açık toplayıcı tek dokunuşla ilk boş istasyon yuvasına girer; ikinci yuva seçimi yoktur.
- İlk %75 yaklaşımı, toplama temposu, geri çekilme, 2–4 bağımsız trenin %12 daha yavaş hareketi korunmuştur.
- Lokomotif ilerledi diye arka vagonlar uzaktan alınmaz. Her vagon kendi fiziksel mesafesiyle uygun olmalıdır.
- Aynı renkli toplayıcılar geliş sırasını korur. Kapasite bitince yuva boşalır. Tren sona ulaşırsa kaybedilir.
- Dondur 5 saniye; Patlat en fazla 5 uygun parçayı mevcut toplayıcı kapasitesiyle alır; Geri al son toplayıcıyı kalan kapasitesiyle geri getirir.
- 3 temel yuva + 1 kalıcı VIP + 1 bölüm başına ödüllü yuva. Toplam en çok 5.
- Dondur/Patlat 0, Geri al 1 hakla başlar. Sonraki haklar tamamlanmış ödüllü reklam sonucuna bağlıdır.
- VIP olmayan oyuncuda her 2 galibiyetten sonra bölüm geçişi reklam noktası vardır.

**Gerçek reklam ve ödeme SDK'ları bağlı değildir.** Kaynak Godot paketinde de sağlayıcılar devre dışıydı. Unity'de `ICommerce` bağlantı arayüzü vardır; varsayılan `UnavailableCommerce` satın alma veya reklam izlemiş gibi ödül vermez. VIP ürün kimliği `com.bedogames.renkekspresi.vip_lifetime`, Türkiye fiyat hedefi 299,98 TL'dir. Gerçek fiyat mağazadan gelmelidir. Sıralamadaki örnek isimler açıkça kurgusal olarak belirtilir; çevrimiçi yarış altyapısı yoktur.

## Kaynak düzeni

| Klasör / dosya | İşlev |
|---|---|
| `Assets/RenkEkspresi/Core/PuzzleEngine.cs` | Unity'den bağımsız deterministik bulmaca motoru |
| `Core/LevelData.cs` | Bölüm, toplayıcı, vagon ve yuva verileri |
| `Core/Commerce.cs` | Ödeme/reklam bağlantı sözleşmesi ve ödül tekrar koruması |
| `Runtime/GameManager.cs` | Oyun akışı, giriş, sonuç, menüler ve yardımcılar |
| `Runtime/GameWorld.cs` | 3D harita, sabit kamera, etkileşim ve görsel geri bildirim |
| `Runtime/TrainModels.cs`, `RailSpline.cs` | Mesh yükleme ve ray üzerinde görselleştirme |
| `Runtime/GameUI.cs` | Arayüz, ekran güvenli alanı, düğmeler, pencereler |
| `Runtime/SaveData.cs`, `LegacyMigration.cs` | Kayıt, yedek ve Godot kaydı aktarımı |
| `Runtime/AudioManager.cs`, `Haptics.cs` | Ses ve titreşim |
| `Resources/Data` | 100 bölüm, 100 ray dosyası ve mağaza hedefleri |
| `Resources/Models` | Orijinal geometriden aktarılmış gerçek mesh verileri |
| `Resources/Prefabs` | Unity ilk açılışında üretilen düzenlenebilir tren prefabları |
| `Editor` | Proje ayarları, prefab üretimi, bölüm denetçisi ve derleme menüsü |
| `Verification` | Eski motor izleri, C# karşılaştırma testleri ve sonuçlar |

Trenin biçimini değiştirmek için ilk importtan sonra `Resources/Prefabs` içindeki prefabı aç. Mesh bileşenini kendi modelinle değiştirebilirsin. Prefab üreticisi mevcut prefabların üzerine yazmaz. Materyal/ışık/çevre ve UI parametreleri ilgili C# dosyalarındadır; haritalar çalışma anında oluşturulur. Bu ilk geçiş paketinde her bölüm için ayrı elle kurulmuş Unity sahnesi bulunmaz.

## Eski kayıtların korunması

Unity kaydı ayrı bir `renk_ekspresi_unity_v1.json` dosyasına yazılır; Godot kaydı silinmez. Unity kaydı bulunmazsa aynı uygulama alanındaki ve bilinen masaüstü/Android yollarındaki `renk_ekspresi_player_v1.json` veya `.bak` okunmaya çalışılır. Bölüm ilerlemesi, dil, ses, öğretici durumu ve standard/assisted rekorları taşınır. Eski `test_vip` / `test_paid` alanları satın alma sayılmaz.

Aynı bundle ID korunmuştur. Yine de gerçek iPhone/Android üzerinde **eski sürümün üzerine güncelleme testi yapılmadı**. Uygulamayı silip yeniden kurmak kayıtları kaldırabilir. Godot tarayıcı kaydı Unity WebGL'e otomatik aktarılmaz; tarayıcı depoları farklıdır.

## Derleme

İlk olarak Editor Play testi yapılmalıdır. İlgili platformun Build Support modülünü Unity Hub'dan ekle.

- **WebGL:** `Renk Ekspresi → Build → WebGL preview`. Çıktı `Builds/WebGL` olur. Klasörü bir HTTP(S) sunucusunda aç; `index.html` dosyasına çift tıklama. `online.txt` de dağıtıma dahil olmalıdır.
- **iOS:** macOS + iOS Build Support gerekir. `APPLE_TEAM_ID` ve önceki yüklemeden yüksek bir `RENK_EKSPRESI_BUILD_NUMBER` ortam değişkeni ayarla; `Build → iOS Xcode project`. Üretilen `Builds/iOS` projesini Xcode'da aynı uygulama kaydıyla imzalayıp Archive/Validate yaptıktan sonra TestFlight'a yükle.
- **Android test:** `RENK_EKSPRESI_BUILD_NUMBER` ayarla; `Build → Android test APK`.
- **Android yayın:** Aynı uygulamanın geçerli upload key'iyle `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` değişkenlerini sağla; `Build → Android signed AAB`.

Şifreler kaynakta tutulmaz. Önceki Godot Codemagic dosyası bu projeyi derlemez; Unity etkinleştirmesi ve Unity derleme adımı gerekir. Bu pakette çalışan bir Codemagic/TestFlight yüklemesi yapıldığı iddia edilmez.

Komut satırından örnek WebGL derlemesi:

```bash
"/path/to/Unity" -batchmode -quit -projectPath "/path/to/Renk_Ekspresi_Unity" -buildTarget WebGL -executeMethod RenkEkspresi.Editor.ProjectTools.BuildWeb -logFile unity-build.log
```

## Yayına geçmeden önce kalanlar

Unity import/Play ve WebGL/IL2CPP derlemesi; gerçek iPhone/Android üzerinde dokunma, güvenli alan, ses ve performans; Godot'tan güncelleme/kayıt testi; gerçek reklam SDK'sı, doğrulanmış mağaza satın alımları ve geri yükleme; mağaza metinleri/ikonları/gizlilik beyanlarının son kullanılan SDK'larla eşleştirilmesi. Örnek sıralama gerçek küresel sıralama gibi sunulmamalıdır.

## Kaynaklar

- Unity sürümü: https://unity.com/releases/editor/whats-new/6000.0.60f1
- Unity komut satırı: https://docs.unity3d.com/6000.0/Documentation/Manual/EditorCommandLineArguments.html
- Json.NET Unity paketi: https://docs.unity3d.com/Packages/com.unity.nuget.newtonsoft-json@3.2/manual/index.html
- Kayıt yolu: https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Application-persistentDataPath.html

Varlık bildirimleri `ASSET_LICENSES.txt` ve font lisansındadır. Önceki Godot paketinden gelen bildirimler kökeni korumak amacıyla tutulmuştur; Unity çalışma zamanı Godot kullanmaz.
