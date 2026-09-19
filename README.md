# ÇekSepet iOS

Android Compose ekranları ve aynı klasördeki Go backend incelenerek hazırlanmış, Swift / SwiftUI tabanlı iPhone ve iPad uygulaması. Minimum iOS 17. Harici Swift paketine, CocoaPods'a veya Firebase'e ihtiyaç yok.

[Doğrulama raporu](Docs/Validation.md) · [Endpoint eşlemesi](Docs/API-Mapping.md) · [Ekran görüntüleri](Docs/Screenshots/README.md)

## Xcode'da açma ve iPhone'da çalıştırma

1. `CekSepet.xcodeproj` dosyasını Xcode'da açın. Proje hazırdır; yeniden oluşturmanız gerekmez.
2. `CekSepet` target → **Signing & Capabilities → Team** alanında kendi Apple hesabınızı seçin. Gerekirse `com.ceksepet.ios` Bundle Identifier değerini değiştirin.
3. iPhone'u Mac'e bağlayın; iPhone'da geliştirici modunu açın, Xcode üst menüsünde cihazınızı seçin ve **Run (⌘R)** kullanın.
4. Giriş ekranının altındaki **Bağlantı ayarları** bölümünden API adresinizi girin. Örneğin `http://192.168.1.20:8080/api/v1/` veya gerçek HTTPS sunucu adresiniz. Ayar yalnızca Debug sürümünde bulunur.

Simülatörün varsayılan adresi `http://localhost:8080/api/v1/`. Gerçek iPhone'da `localhost`, iPhone'un kendisidir: Mac'in aynı ağdaki IP adresini kullanın. Backend `:8080` üzerinden dinlemeli, güvenlik duvarı bağlantıya izin vermeli ve MongoDB bağlantısı çalışmalıdır. Android emülatör adresi `10.0.2.2` iOS için kullanılmaz.

Backend'i kendi klasöründe mevcut README'sine göre başlatın. iOS projesi backend `.env` dosyasını okumaz ve içermez. SMS gönderimi backend'in mevcut sağlayıcı ayarlarına bağlıdır. Geliştirme backend'i `debugOtpCode` döndürürse kod yalnızca Debug uygulamasında gösterilir.

## Tamamlanan ekranlar ve akışlar

- Üç sayfalı, kaydırılabilir onboarding; Android illüstrasyonları, sarı `#FFCB0A`, koyu `#232323`, gri `#848484`, yeşil göstergeler ve kart düzeni.
- Telefon + 6 haneli PIN ile giriş → SMS doğrulama.
- Ad, soyad, telefon, PIN → sunucudan avatar listesi → avatar seçimi → sunucunun oluşturduğu kullanıcı adı → kayıt SMS doğrulaması.
- OTP tekrar gönderme, kalan süre, süresi dolan işlemden yeniden başlama, alan hataları, PIN/OTP deneme sınırı ve sunucu `retryAfter` desteği.
- Keychain oturumu; açılışta ve öne dönüşte `users/me` kontrolü. Bağlantı hatasında token korunur; yalnızca sunucunun `UNAUTHORIZED` yanıtında oturum geçersiz sayılır.
- Ana sayfa, ürün detayı, çalışan metin araması ve kategori filtreleri, paylaşım, hesaba göre cihazda favoriler.
- Ürün taslağı oluşturma/düzenleme/silme, dört fotoğrafa kadar sistem fotoğraf seçici ve kamera, fotoğraf boyutlandırma, alan doğrulama, atomik cihaz kaydı.
- Profil, yenileme, cüzdan/bilet/bildirim durum ekranları, sayfalı gerçek topluluk listesi, yardım, çıkış ve kullanıcı adı + PIN ile onaylı hesap silme.
- VoiceOver etiketleri, Dynamic Type, klavye araç çubuğu, kaydırılabilir formlar, iPad genişlik uyarlaması, uygulama değiştiricide kişisel veri ekranını gizleme, app icon, launch screen ve privacy manifest.

## Mevcut backend sınırları

Backend'in ürün, ürün yükleme, çekiliş, bilet, ödeme, cüzdan, favori senkronizasyonu, push bildirimi, PIN sıfırlama veya sosyal giriş endpointi yok. Android de ürünleri `MockData.kt` dosyasından gösteriyor.

iOS aynı altı ürünü **Örnek katalog** etiketiyle gösterir. Görseller Android'deki gibi yer tutucudur. Bilet sayıları gerçek katılım sayıları değildir; ödeme veya çekiliş yapılmaz. Favoriler ve fotoğraflı taslaklar yalnızca cihazda saklanır; yayınlama ve bulut senkronizasyonu yapılmaz. Misafir verileri hesaba otomatik taşınmaz. Android'deki işlevsiz sosyal giriş düğmeleri aktif bir özellik gibi sunulmaz.

Uygulamanın yazı ve ikonlarında ÇekSepet adı kullanıldı. Kaynak Android illüstrasyonları değiştirilmeden alındığından üçüncü illüstrasyonun içinde eski **Torba** logosu bulunur. Tam marka güncellemesi için ilgili kaynak görsel değiştirilmelidir.

Backend avatar kataloğundaki sekiz SVG'nin şekilleri SwiftUI Canvas ile aynen çizilir. Katalogdaki ID ve adlar canlı API'den gelir. Backend'e yeni avatar şekilleri eklenirse `Design/Components.swift` içindeki çizim kataloğu da güncellenmelidir.

## Proje yapısı

```text
CekSepet/
  App/          Uygulama başlangıcı, onboarding ve oturum yönlendirmesi
  Core/         API istemcisi, DTO'lar, Keychain, oturum ve cihaz deposu
  Design/       Android renkleri, ortak form/kart bileşenleri, avatar çizimi
  Features/     Kayıt/giriş/OTP, katalog, ürünler, profil, taslaklar ve yardım
  Resources/    Android görselleri, app icon, Info.plist ve privacy manifest
Config/         Debug/Release API adresleri
CekSepetTests/  API sözleşmesi, hata, oturum ve cihaz deposu testleri
CekSepetUITests/ Ekrandan gerçek Go handler'larına giden UI testleri
TestSupport/    Bellekte çalışan test sunucusu başlatıcısı
Scripts/        Test backend'i ve ikon üretimi
Docs/           Endpoint eşlemesi ve doğrulama raporu
```

## Testler

Arayüz testleri için önce ayrı terminalde:

```sh
python3 Scripts/run_test_backend.py
```

Bu yardımcı, kardeş Go projesinin kaynaklarını geçici klasöre kopyalar ve gerçek HTTP handler'larını backend'in mevcut test belleği deposuyla `127.0.0.1:18080` üzerinde açar. `.env` kopyalamaz, MongoDB'ye bağlanmaz, SMS göndermez. Test hesabı `5551112233`, PIN `123456`; SMS kodları gerçekten üretilir ve yalnızca test geliştirme yanıtında görülür. Test sunucusu sadece bilgisayarın loopback adresinde dinler ve fiziksel telefondan erişilmez. Bitince Ctrl+C ile kapatın.

Xcode'da **Product → Test (⌘U)** veya:

```sh
xcodebuild -project CekSepet.xcodeproj -scheme CekSepet \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -derivedDataPath build test
```

Sadece birim testleri için `-only-testing:CekSepetTests` ekleyin; test backend'i gerekmez. Yerel simülatörünüze göre destination değerini değiştirin. Keychain testleri için imzalamayı kapatmayın: `CODE_SIGNING_ALLOWED=NO` ile çalıştırılan simülatör uygulaması Keychain yetkilerini kaybeder. Simülatörde varsayılan yerel Xcode imzası Apple geliştirici takımı gerektirmez.

## Release yapılandırması

`Config/Local.xcconfig.example` dosyasını `Config/Local.xcconfig` olarak kopyalayın; HTTPS API adresini ve Apple Team değerini girin. Bu dosya Git dışında tutulur. Release varsayılan adresi bilerek boştur; bilinmeyen bir production adresi uydurulmamıştır. Release'te uygulama içinden adres değiştirilemez ve HTTP URL'leri kabul edilmez.

```xcconfig
API_BASE_URL = https:/$()/api.your-domain.com/api/v1/
DEVELOPMENT_TEAM = YOUR_APPLE_TEAM_ID
```

`/$()/` yazımı Xcode config dosyalarının `//` karakterlerini yorum saymasını önler. API anahtarları, MongoDB bağlantı metni veya SMS sağlayıcısı sırları mobil uygulamaya eklenmez.

App Store/TestFlight dağıtımı için kendi imzanız, gerçek HTTPS backend/SMS hizmeti ve mağaza bilgileriniz gerekir. Ürün/ödeme/çekiliş servisleri tanımlanmadan bu işlevler canlı kullanıma açılamaz. Cihazda kamera, gerçek SMS otomatik doldurma ve yerel ağ izinleri fiziksel iPhone'da ayrıca doğrulanmalıdır.

Proje dosyasını yeniden üretmek isterseniz: `brew install xcodegen`, ardından `xcodegen generate`. Kaynak proje tanımı `project.yml` dosyasıdır.

Uygulanan Apple API referansları: [Keychain erişim sınıfı](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly), [PhotosPickerItem](https://developer.apple.com/documentation/photosui/photospickeritem), [Yerel ağ ATS ayarı](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).
# cek-sepet-ios
