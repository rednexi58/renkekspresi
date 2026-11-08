# Renk Ekspresi — Godot 4.5.1

Oyunun yeni ve tek geçerli kaynağı bu klasördür. `Godot/` (v0.28) ve `Renk_Ekspresi_Unity/` klasörleri yalnızca referans olarak tutulur; taşıma bitince kaldırılacaktır.

## Klasör yapısı

| Klasör | Sorumluluk |
| --- | --- |
| `core/level` | Bölüm verisinin modeli ve `campaign.json` okuma (`Campaign`, `LevelDefinition`, `CollectorDefinition`) |
| `core/puzzle` | Oyun kuralları: `PuzzleEngine` (tren, istasyon, eşleşme, yardımcılar) ve `CollectorYard` (ok yönü engelleri, anahtar kilitleri) |
| `core/policy` | Küçük, bağımsız kurallar: `LanguagePolicy`, `RewardGuard` |
| `data` | 100 bölüm (`campaign.json`) ve her bölümün ray çizgisi (`routes/route_XXX.json`) |
| `tests` | Headless test koşucusu, test grupları ve orijinal oyundan kaydedilmiş referans oynanışlar |

## Mimari kararlar

- **Kurallar saf mantıktır.** `core/` içindeki hiçbir sınıf Node, sahne ya da çizim bilmez. Böylece kurallar ekran olmadan test edilir ve görsel katman kuralları değiştiremez: vagonu yalnızca `PuzzleEngine` kaldırır, ödülü yalnızca kurallar verir.
- **Sabit adımlı simülasyon.** `tick()` geçen süreyi 0,025 saniyelik adımlara böler. Sonuç kare hızından bağımsızdır; 60 FPS ve 120 FPS iPhone'da aynı hamle aynı sonucu verir.
- **Bahçe geometrisi ayrı bir sınıftır.** "Hangi toplayıcı çıkabilir" sorusu tren zamanlamasından bağımsızdır. `CollectorYard` ayrı olduğu için ipucu sistemi ve "seni engelleyen bu" vurgusu simülasyona dokunmadan aynı kuralı kullanır.
- **Sonuçlar metin değil enum'dur** (`ChooseResult`, `BoosterResult`, `Status`). Yazım hatası derleme aşamasında yakalanır, oyuncuya gösterilecek mesajın dili de arayüz katmanında seçilir.
- **Veri ayrı yüklenir.** Dosya ve JSON erişimi yalnızca `Campaign` içindedir; bölümler ileride uzaktan güncellenecekse değişecek tek yer burasıdır.

## Testler

```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/run_tests.gd
```

- `parity` grubu, orijinal v0.34 oyunundan kaydedilmiş 116 oynanışı (100 bölüm çözümü ve 16 uç durum) yeniden oynatır. 4.471 anlık görüntüde süre, tren başı, vagon konumları, yuvalar, kapasiteler, yardımcı stokları ve hedefler 0,00025 toleransla karşılaştırılır.
- `rules` grubu şunları doğrular: hiçbir şey yapılmayan her bölüm kaybedilir; engelli ya da kilitli seçim reddedilir; ek yuvalar tam bir kez verilir; ödül callback'i iki kez ödül veremez; dil seçimi doğru çalışır; 100 bölümün tamamı ve ray dosyaları eksiksizdir.

Komut başarılıysa 0, ilk hatada 1 çıkış koduyla biter; CI bu kodu kullanır.
