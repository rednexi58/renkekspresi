# Renk Ekspresi — Görsel yenileme 0.41

Bu paket mevcut Unity projesine uygulanır. Uygulama kimliği, kayıt dosyası, bölüm verileri,
Unity iOS imzalama ayarı ve son çalışan simge düzeltmesi korunmuştur.

## Yükleme — önce Unity, sonra Codemagic

1. Renk_Ekspresi_Unity_Gorsel_Guncelleme_v041.zip dosyasını bilgisayarda çıkar.
2. GitHub'da rednexi58/renkekspresi deposunun ANA SAYFASINI aç (codemagic.yaml'ın göründüğü yer).
3. Add file > Upload files seç. ZIP'in içindeki Renk_Ekspresi_Unity KLASÖRÜNÜ sürükle.
   ZIP dosyasının kendisini yükleme. Klasör başka bir Renk_Ekspresi_Unity klasörünün içine girmemeli.
4. Commit changes ile main dalına kaydet. Mevcut dosyaları veya Godot klasörünü silme.
5. Unity Cloud > Build Automation > Renk Ekspresi iOS TestFlight > Build.
   Branch main; commit alanı boş. Replay Build kullanma. Sertifikaları değiştirme.
6. Başarılı YENİ build'in Share bağlantısını al. Codemagic'teki share_id bu yeni bağlantıyla
   güncellenmeden Codemagic'i çalıştırma; aksi hâlde eski 43 numaralı IPA tekrar gönderilir.
7. Codemagic upload sonrasında App Store Connect > TestFlight > yeni build > knk iç test grubu.
   Şifreleme formu çıkarsa o build'in kullandığı algoritmalara göre bildirimi tamamla.

Kaynak sürümü 0.41, TestFlight build numarası değildir. Build numarasını mevcut
IosBuildVersionGuard, Unity Cloud build sayısına göre atamaya devam eder.

## Değişenler

- Yönler fonttan bağımsız, koyu konturlu beyaz geometrik oklarla çizilir.
- Ok yönü dikdörtgen park ızgarasının ve sabit kameranın gerçek izdüşümünden hesaplanır.
  Çapraz oklar gerçekten engel olan vagona doğrultulmuştur.
- Kapasite ayrı koyu rozet içinde gösterilir. [A] kilit, +A anahtar vagonu anlamındadır.
- Engelli seçimde seçilen vagon ve engelleri kısa süre vurgulanır; mesajlar üst üste birikmez.
- Üstte tren yolu, altta yakın vagon sahası: iki sabit ortografik kadraj. Kamera takip etmez.
- Dokunma seçimi ortak bir düzlemde yapılarak öndeki 3D kutunun arka sıranın dokunuşunu
  yakalaması önlenir. Menü dışındaki dekoratif UI öğeleri dokunmaları engellemez.
- Yeni, kaynak geometrisi düzenlenebilir lokomotif ve beş renkli yuvarlak çatılı vagon.
- Yeni modeller eski önbelleğe alınmış prefabların altında kalmaz; güncel kaynak mesh kullanılır.
- Ray yatağı, etkin fiziksel eşleşme yolunun görsel işareti, evler ve bölge dekorları yenilendi.
- Yeni krem/lacivert arayüz, ayrı kapasite rozetleri, vektör yardımcı ikonları, daha geniş ses
  kaydırıcıları, güvenli ekran alanı ve masaüstünde dikey oyun çerçevesi.
- iOS build sırasında doğrusal renk uzayı ve dikey görünüm uygulanır.
- Sesler, 100 bölümün kuralları, hızlar, VIP/ödül kuralları ve kayıtlar bu pakette değiştirilmedi.

## Yapılan kontroller

- .NET 8 ile gerçek C# bulmaca motoru çalıştırıldı: 100 bölüm çözüm kaydı + 16 kenar durum,
  4.471 durum karşılaştırması ve 100 boşta kaybetme koşusu; 380.199 doğrulama geçti.
- 100 bölüm/rota ve kaynak varlık denetimi geçti.
- Yeni mesh üçgenleri, normal yönleri, 1.546 ok/engel ilişkisi ve 600 ekran/bölüm
  kadraj hesabı geçti. Hesap testi gerçek dokunma veya Unity render testi değildir.
- 80 C# ayrıştırma kontrolü geçti. Bu, Unity API bağlama/oynatıcı derlemesi değildir.
- Yeni modeller gerçek JSON mesh kaynaklarından ayrı bir EGL renderer ile görüntülendi.
  Bu model ön izlemesi Unity oyununun ekran görüntüsü değildir.
- Vagon başına köşe sayısı 43.954'ten 4.694'e, lokomotif 70.784'ten 5.068'e indi.
  Gerçek cihaz FPS'i ölçülmedi.

## Açık kalan kontroller — dürüst sınırlar

Burada Unity Editor, Xcode veya iPhone çalıştırılmadı. Unity derlemesi, shader çıktısı,
iPhone dokunmaları, tam UI görünümü, güvenli alan ve FPS son Cloud build/TestFlight'ta
kontrol edilmelidir. Bu ZIP IPA değildir; App Store'a hazır olduğuna dair bir onay değildir.

Mevcut kaynakta reklam/satın alma için UnavailableCommerce kullanılıyor: gerçek SDK
bağlantısı olmadan reklam veya VIP satın alma yapılamaz. Bunlar bu görsel pakette bağlanmadı.
Sıralama hâlen açıkça örnek olarak işaretlenen kurgusal listedir; gerçek Game Center değildir.

## Telefonda öncelikli deneme

- 1. bölüm: ok yönü, tek dokunuş, ilk boş yuva, sayı azalması.
- 10. bölüm: iki trenin aynı yuvaları paylaşması ve kadraj.
- 27. bölüm: 5 satır, çapraz oklar, engellenen yön, anahtar/kilit.
- 50/100: 4 tren, kalabalık sahne, uzun süreli performans ve ısınma.
- Ayarlar: üç ses kaydırıcısı, dil, düşük grafik; ardından oyuna dönme.
- Ekranı kilitle/aç: duraklama, devam ve kayıt.
- Kazan/kaybet/yeniden başlat: UI geçişleri ve eski animasyonun yeni sahneye taşmaması.

Bölümler test için otomatik açılmaz; mevcut ilerleme korunur. Unity Editor'deki
Renk Ekspresi > Level inspector ile bölüm seçimi yapılabilir.
