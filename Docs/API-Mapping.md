# Backend → iOS eşlemesi

Kaynak sözleşme: kardeş Go projesindeki `internal/httpapi/server.go`, `types.go`, `flow.go`, `account.go`, `avatars.go`, `validation.go` ve `openapi.yaml`. Android'in Retrofit DTO'ları ve ekranları ayrıca karşılaştırıldı.

| Yöntem ve yol (`/api/v1` altında) | iOS kullanımı | Yetkilendirme |
|---|---|---|
| GET `avatars` | Kayıtta avatar seçimi | Yok |
| POST `auth/register/step-1` | Ad/soyad/telefon/PIN; `registrationToken` alır | Yok |
| POST `auth/register/step-2` | `registrationToken` + `avatarId`; kullanıcı adı ve SMS bilgisi | Yok |
| POST `auth/register/otp/verify` | `registrationToken` + `otpCode`; kullanıcı ve access token | Yok |
| POST `auth/register/otp/resend` | Sadece `registrationToken` | Yok |
| POST `auth/login` | Telefon + PIN; `loginToken` alır | Yok |
| POST `auth/login/otp/verify` | `loginToken` + `otpCode`; kullanıcı ve access token | Yok |
| POST `auth/login/otp/resend` | Sadece `loginToken` | Yok |
| GET `users/me` | Başlangıç, öne dönüş ve profil yenileme | Bearer |
| POST `auth/logout` | Sunucu oturumunu iptal eder; 204 | Bearer |
| DELETE `users/me` | JSON gövdede `username` ve `pin`; 204 | Bearer |
| GET `users?limit=20&offset=N` | Sayfalı topluluk, hassas alanlar olmadan | Yok |

`/api/v1/operator/*` yönetici API'sidir ve müşteri uygulamasına bağlanmadı. `/health/*`, `/swagger/*` mobil kullanıcı ekranı değildir. `/avatars/*.svg` görsellerinin mevcut sekiz şekli native çizilir; `avatarUrl` DTO'da korunur.

## Kritik sözleşme ayrıntıları

- Backend `DisallowUnknownFields` kullanır. Login ve kayıt gövdeleri ayrı Codable modelleridir. Bir isteğe diğer akışın tokenı veya fazladan alan gönderilmez.
- Kayıt/login tokenları sadece bellek içindedir; access token yalnızca başarılı SMS doğrulaması sonrasında Keychain'e yazılır. PIN ve SMS kodları kalıcı kayda veya uygulama loglarına yazılmaz.
- Keychain hesabı normalleştirilmiş API URL'sine göre ayrılır. Farklı sunucuya önceki sunucunun tokenı gönderilmez. HTTP yönlendirmeleri reddedilir.
- Çıkışta 204 beklenir. Bağlantı hatasında sunucu iptal edilmiş gibi davranılmaz; oturum korunur ve tekrar denenebilir. `UNAUTHORIZED` zaten iptal edilmiş oturum olarak ele alınır.
- Hesap silmenin 401 `INVALID_CREDENTIALS` yanıtı yanlış PIN/kullanıcı adıdır; oturum düşürülmez. 401 `UNAUTHORIZED` geçersiz oturumdur.
- 429 yanıtındaki `retryAfter` ve `fieldErrors` arayüzde işlenir. OTP ve yeniden gönderme sayaçları mutlak tarihe göre çalışır; uygulama arka plana gidince bekleme süresi donmaz.
- Açılışta offline olma/500/yanlış JSON erişim anahtarını silmez. Kullanıcı tekrar deneyebilir. Sunucunun hata mesajı ve alan hataları korunur; JSON olmayan proxy yanıtı anlaşılır bağlantı hatasına çevrilir.
- `REGISTRATION_SESSION_EXPIRED`, `LOGIN_SESSION_EXPIRED`, `INVALID_REGISTRATION_STEP` akışı yeniden başlatır; `OTP_EXPIRED` yeni kod istemeyi sağlar; `OTP_ATTEMPTS_EXCEEDED` doğrulamayı yeni kod gelene kadar kapatır.

## Tam canlı katalog için backend'de eksik sözleşmeler

Ürün liste/detay/yayın/düzenleme/silme, fotoğraf yükleme, sunucu favorileri, satıcı profili, bilet edinme/katılma/sonuç, cüzdan/bakiye/işlem geçmişi, ödeme sağlayıcısı geri dönüşleri, push cihaz kaydı/bildirimler ve PIN sıfırlama. Bunların yolları, veri modelleri ve iş kuralları mevcut kaynakta tanımlı değildir. iOS istemcisi bu işlemler için hayali endpoint veya başarılı işlem üretmez.
