# Renk Ekspresi 0.28.0 — çevre ve bölüm akışı testi

Bu paket kaynak projedir; imzalanmış IPA değildir. Mevcut 0.27 paketini yedek tutun.

## Değişiklikler
- 1–5: kıyı, deniz köpüğü şeritleri ve deniz feneri.
- 6–10: yoğun ağaç grupları, nehir ve kereste çevresi.
- 11–15: granit sırtlar, kar örtüsü ve dağ duvarları.
- İlk 15 bölümün ray varyantları yeniden sıralandı. Çift tren 10 ve 15'te korundu.
- Çift numaralı ilk bölümlerde park yerleşimi ve ok yönleri birlikte aynalandı.
- 11. bölüm, çift tren tanıtımından sonra daha kısa bir nefes bölümü olarak düzenlendi.
- Türkçe/İngilizce bölge ve bölüm başlıkları; süre/hamle/temizlenen parça kartları ve animasyonlu bölge ilerlemesi.
- 16–100 bölüm verileri ve çekirdek toplama/fren/yuva kuralları korunmuştur.

## GitHub ve TestFlight
ZIP'i açın. İçeriği mevcut renkekspresi deposunun köküne yükleyerek aynı yolları güncelleyin. Yeni region_scenery.gd dosyası da yüklenmelidir. Commit edin.
Codemagic renk_ekspresi_ios grubunda RENK_EKSPRESI_BUILD_NUMBER değerini 28 yapın (28 daha önce kullanıldıysa daha yüksek kullanılmamış sayı).
APPLE_TEAM_ID, Apple AppStore entegrasyonu ve mevcut profil değişmez.
main dalında yeni build başlatın. Sürüm 0.28.0 olarak derlenir. Apple işlemesi sonrası mevcut TestFlight grubuna yeni build'i ekleyin.

## Test rotası
Yerel otomatik testler: 100 bölümün çözüm/renk kapasitesi ve fiziksel eşleşme kontrolleri, yuva/skor/dil kontrolleri, ilk 15 bölümün iki dilde sahne/sonuç ekranı kontrolleri hatasız tamamlandı. Bunlar gerçek cihazdaki görsel kaliteyi doğrulamaz.
Admin bölüm panelinden 1, 5, 6, 9, 10, 11, 14, 15'i deneyin. İlk 15'i ayrıca sırayla oynayın.
Dokunma alanlarına dekor girmesi, küçük ekranda yazı taşması, kare hızı ve bölge geçişinin belirginliğini kontrol edin.
Test modunda reklam/satın alma simülasyondur; çevrim içi sıralama eklenmemiştir.
Yerel ortamda iOS cihaz testi ve GPU ekran görüntüsü doğrulaması yapılamadı. Telefon performansı veya 60 FPS garantisi verilmez.
İlk beş bölüm bilinçli kolay; 6–8 de halen affedicidir. Bu sürüm zorluk eğrisinin nihai onayı değildir.
