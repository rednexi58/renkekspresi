> Oyun adı: **Renk Ekspresi**. İngilizce adı: **Color Express**.
> Apple'da mevcut uygulamanın görünen adını App Information bölümünde değiştir; sırf ad değişti diye yeni uygulama kaydı açma.
> `com.bedodrive.trainjam3d` teknik kimliği önceki Apple kaydıyla uyum için korundu; oyuncuya görünen oyun adı değildir.
> Bu pakette Codemagic bağlantı adı `RenkEkspresiApple`, değişken grubu `renk_ekspresi_ios`, build değişkeni `RENK_EKSPRESI_BUILD_NUMBER` olarak yenilendi. Eski adlarla bağlantı kurduysan panelde bunları da aynı şekilde adlandır.

# Renk Ekspresi v0.27 — TestFlight hazırlık paketi

**Bu dosya bir kaynak/derleme paketidir; imzalı IPA değildir.** Linux ortamında oyun kuralları ve arayüz akışları test edildi. macOS/Xcode derlemesi, Apple imzası ve TestFlight yüklemesi henüz yapılmadı. İlk Codemagic derlemesinin sonucu görülmeden “TestFlight'a hazır IPA” olarak değerlendirmeyin.

## Oyunda hazır olanlar

3 temel yuva + VIP ile 1 kalıcı yuva + reklamla bölüm boyunca 1 yuva + ayrı satın almayla 1 kalıcı yuva. Her hak bir kez verilir; toplam en fazla 6. VIP ve ayrı yuva birlikte alınabilir. Bu testte satın alma ve reklamlar açıkça ücretsiz simülasyondur. Gerçek ödeme alınmaz.

Türkçe/İngilizce: Ayarlar > Language / Dil. İlk açılışta cihaz dili seçilir. İlerleme ve süre tablosu bu cihazda saklanır. Standart (3 yuva, ipucu/geri alma/kurtarma yok) ve destekli koşular ayrı tutulur. Admin/test koşuları ayrıca işaretlenir; dünya sıralaması değildir.

## 1. Bu oyun için Apple kaydını aç

Apple Developer > Certificates, Identifiers & Profiles > Identifiers içinde App ID oluştur. Önceki paketle aynı tutulan teknik Bundle ID: `com.bedodrive.trainjam3d`. Önce hesabında kullanılabilirliğini doğrula. Başka oyunun kimliğini kullanma.

App Store Connect > Apps > + > New App: iOS, Renk Ekspresi (adı kullanılabilir olmalı), ana dil seçimi, bu Bundle ID, SKU `trainjam3d-ios`. Ana dil, oyunun diğer dili desteklemesini engellemez. Bundle ID farklı seçilirse Godot/export_presets.cfg ve codemagic.yaml içindeki iki kimliği birlikte güncelle.

## 2. Kaynağı kendi Git depona koy

ZIP'i aç. `codemagic.yaml`, `ci/` ve `Godot/` aynı kök dizinde olacak şekilde kendi özel GitHub deposuna yükle. İç içe fazladan klasör bırakma. `.git`, `.godot`, derleme önbelleği veya imzalama anahtarlarını yükleme. Codemagic bu depoyu okuyacak. Bu sohbetin oyun test adresi kaynak depo adresi değildir.

## 3. Apple bağlantısını Codemagic'e ekle

Codemagic > Team settings > Integrations içinde App Store Connect bağlantısını `RenkEkspresiApple` adıyla oluştur. App Store Connect > Users and Access > Integrations > App Store Connect API üzerinden gerekli anahtarı oluşturup Issuer ID, Key ID ve .p8 dosyasını Codemagic'in ilgili güvenli alanına gir. Anahtarı sohbete veya Git'e gönderme. Kullanılan rolün uygulama yüklemeye yetkili olması gerekir.

## 4. İmzalama ve iki değişken

Codemagic > Code signing identities içinde Apple Distribution sertifikası ve **bu Bundle ID için App Store provisioning profile** tanımla. TestFlight için distribution type `app_store` olmalı. Mevcut sertifika yeniden kullanılabilir; provisioning profile oyunun Bundle ID'siyle eşleşmeli.

`renk_ekspresi_ios` adlı environment variable grubuna şunları ekle:

| Değişken | Değer |
|---|---|
| APPLE_TEAM_ID | Apple Developer üyeliğindeki 10 karakterlik Team ID |
| RENK_EKSPRESI_BUILD_NUMBER | İlk deneme için 27; her sonraki yüklemede 28, 29… Daha önce kullanılan numarayı tekrar kullanma. |

Team ID, Apple ID e-posta adresi değildir. Şifre/anahtar değişkeni bu kaynakta bulunmaz.

## 5. İlk derlemeyi çalıştır

Codemagic'e depoyu ekle, YAML yapılandırmasını seç. Workflow: `renk-ekspresi-ios-playtest`. Start new build ile başlat.

Akış: ayar kontrolü → Godot ve iOS şablonları → proje içe aktarımı → yuva/skor/dil testleri → Xcode projesi → provisioning → IPA → App Store Connect'e yükleme. `xcode: latest` kullanılır; Apple'ın 22 Ekim 2026'da doğrulanan minimum şartı Xcode 26 ve iOS 26 SDK'dır. Godot sürümü mevcut projeyi korumak için 4.5.1 olarak sabitlenmiştir; bu kombinasyonun gerçek CI sonucu henüz doğrulanmadı.

Bir adım başarısız olursa o adımın son hata satırlarını paylaş; gizli anahtarları paylaşma. Özellikle ilk native export/imzalama işleminde ayar düzeltmesi gerekebilir.

## 6. TestFlight'ta kendi telefonunda aç

Başarılı yüklemenin ardından App Store Connect > Renk Ekspresi > TestFlight bölümünde build'in işlenmesini bekle. İstenirse ihracat/şifreleme sorularını uygulamanın gerçek özelliklerine göre cevapla. Internal Testing altında kendi yetkili hesabının bulunduğu gruba build'i ekle. Telefonda TestFlight uygulamasını yükleyip daveti aç.

Bu YAML dosyası **genel App Store incelemesi veya dış test incelemesi başlatmaz** (`submit_to_testflight: false`, `submit_to_app_store: false`). Yükleme sonrasında iç test grubu seçimi panelde yapılır. Dış testçiler için beta bilgileri ve Apple beta incelemesi ayrıca gerekir.

## 7. Telefonda kontrol et

1, 10, 25, 50 ve 100. bölümleri aç. Türkçe ve İngilizce menüleri; ekran çentiklerini; perondaki VIP/AD/SHOP hedeflerini; üç hakkın farklı sırayla açılmasını; oyundan çıkıp dönmeyi; kayıt ve sesleri kontrol et. Reklamı iptal edince hak verilmemeli. Yeniden başlatınca yalnızca reklam yuvası kapanmalı.

## 8. Gerçek satış ve dünya sıralaması — henüz tamamlanmadı

App Store Connect'te iki ayrı **Non-Consumable** ürün planlandı:

| Ürün ID önerisi | İçerik | Fiyat |
|---|---|---|
| vip_extra_slot | Bir kalıcı VIP yuvası | Henüz belirlenmedi |
| permanent_extra_slot | VIP'den ayrı bir kalıcı yuva | Türkiye 200 TL, ABD 5 USD hedefi |

Fiyat oyun diline değil mağaza ülkesine göre belirlenir. Apple panelindeki uygun fiyat noktaları doğrulanmalı. Üretimde düğme fiyatı StoreKit'in döndürdüğü yerelleştirilmiş fiyattan okunmalı. Yerel test bayrağı gerçek satın alma hakkı olarak kullanılmamalı.

Gerçek StoreKit işlemleri, satın alımları geri yükleme, iade/bekleyen işlem ve doğrulama bağlantısı **bu pakette yoktur**. Ürünleri panelde açmak bunları kendiliğinden bağlamaz. Ücretli satış için Paid Apps Agreement, banka/vergi bilgileri ve ürün incelemesi de tamamlanmalıdır. TestFlight'ın gerçek StoreKit sandbox işlemleri testçiden para almaz; mevcut ücretsiz test düğmeleri ise henüz StoreKit sandbox bile değildir.

Dünya sıralaması için Apple Game Center veya iOS/Android ortak bir sunucu gerekir. Öneri: ilerlemede ardışık tamamlanan bölüm sayısı; eşitlikte aynı bölümlerin en iyi sürelerinin toplamı. Ayrıca bölüm bazlı süre tablosu. Standart/destekli tablolar ayrı. Admin koşuları gönderilmez; fizik veya harita değişince yeni sezon açılır. Online kimlik, skor doğrulaması, hile engelleme ve veri beyanları yapılmadan sahte oyuncu listesi gösterilmez.

Ödüllü reklam SDK'sı, zorunlu reklam planı ve App Store genel yayını da tamamlanmış değildir. Bu paket ilk native oynanış testi içindir.

## Resmî kaynaklar

- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- https://developer.apple.com/news/upcoming-requirements/
- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/
- https://developer.apple.com/in-app-purchase/
- https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboards/
- https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
- https://docs.godotengine.org/en/4.5/classes/class_editorexportplatformios.html
