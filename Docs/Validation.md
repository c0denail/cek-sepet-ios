# Doğrulama raporu

Tarih: 14 Eylül 2026. Ortam: Xcode 26.4.1, iPhone 17 Pro / iOS Simulator 26.4.1, minimum deployment target iOS 17.0.

## Sonuçlar

| Kontrol | Sonuç |
|---|---|
| Debug simülatör derlemesi | Başarılı; normal Xcode yerel imzasıyla çalıştırıldı |
| Release arm64 iPhone derlemesi | Başarılı; `generic/platform=iOS`, cihaz imzası olmadan derleme kontrolü |
| Swift birim testleri | 12 test geçti |
| Swift UI senaryoları | 4 farklı senaryo geçti |
| Go backend `go test ./...` | Başarılı; MongoDB entegrasyon testleri `MONGODB_TEST_URI` olmadığı için atlandı |
| Info.plist / PrivacyInfo.xcprivacy | `plutil -lint` başarılı |
| Android ve backend dosyaları | Değiştirilmedi; backend Git çalışma ağacı temiz |

## UI senaryoları

1. Onboarding → giriş → örnek katalog → metin araması → ürün detayı → favori.
2. Gerçek Go login handler → üretilen SMS kodu → doğrulama → profil → yanlış hesap silme PIN'i → profil oturumunun korunması.
3. Ürün formu → başlık/marka/açıklama/bilet hedefi → cihazda taslak kaydı → profil taslak listesi → kaydın yeniden açılması.
4. Gerçek Go kayıt adımları → avatar → üretilen SMS kodu → doğrulama → uygulamayı sonlandırıp yeniden açma → Keychain oturumuyla profil → doğru kullanıcı adı ve PIN ile hesap silme → giriş ekranına dönüş.

UI testleri `Scripts/run_test_backend.py` ile açılan **gerçek Go HTTP handler kodu + mevcut test memory store** üzerinde çalıştı. HTTP sözleşmesi ve mobil veri akışı sınandı; MongoDB ve canlı SMS sağlayıcısı kullanılmadı. Fotoğraf seçme ve kamera kodu derlendi; fiziksel kamerayla çekim bu testlerin kapsamına dahil değildir.

## Sonuç dosyaları

- `build/FinalTests.xcresult`: 15/15 geçti (11 birim + 4 UI).
- Son hesap silme eşzamanlılık kontrolünden sonra `build/AccountGuardTests.xcresult`: 13/13 geçti (güncel 12 birim + kayıt/oturum/hesap silme UI senaryosu). Önceki üç UI senaryosunu etkileyen ekran değişikliği yapılmadı.
- [Ekran görüntüleri](Screenshots/README.md): onboarding, giriş, ana sayfa, ürün, profil, avatar, SMS ve ürün taslağı.

İlk simülatör denemesinde imzalamanın kapatılması Keychain erişimini engelledi; normal Xcode yerel imzasıyla giderildi. Kayıt UI testindeki klavye odağı senkronizasyonu düzeltildi ve ilgili senaryo tekrar geçti. Son Release derlemesinde yalnızca kullanılmayan AppIntents metadata çıkarımının atlandığı Xcode araç uyarısı bulunur.

## Fiziksel cihaz ve canlı hizmet sınırı

Apple Team/provisioning kullanılarak fiziksel iPhone'a yükleme yapılmadı. Kamera, gerçek SMS otomatik doldurma, yerel ağ izni ve cihazdaki yaşam döngüsü ayrıca denenmelidir. iPad ve iOS 17 runtime üzerinde ayrı bir çalıştırma yapılmadı; deployment/derleme uygunluğu ve uyarlanan SwiftUI düzenleri sağlandı. Production API adresi verilmediği için canlı sisteme kullanıcı kaydı veya veri yazımı yapılmadı. App Store/TestFlight yayını yapılmadı.
