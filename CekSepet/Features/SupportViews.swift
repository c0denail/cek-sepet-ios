import SwiftUI

struct AvailabilityView: View {
    enum Kind { case wallet, tickets, notifications }
    let kind: Kind
    @Environment(\.dismiss) private var dismiss
    private var title: String { switch kind { case .wallet: "Cüzdan"; case .tickets: "Biletlerim"; case .notifications: "Bildirimler" } }
    var body: some View {
        VStack(spacing: 16) {
            EmptyState(icon: kind == .wallet ? "wallet.bifold" : kind == .tickets ? "ticket" : "bell",
                       title: kind == .notifications ? "Henüz bildirimin yok" : "Çok yakında",
                       detail: kind == .wallet ? "Cüzdan ve ödeme hizmeti henüz kullanıma açılmadı. Şu anda bakiye yüklenemez veya ödeme yapılamaz." : kind == .tickets ? "Bilet satın alma ve çekilişe katılım henüz kullanıma açılmadı. Ürünleri keşfedip favorilerine ekleyebilirsin." : "ÇekSepet bildirim hizmeti açıldığında güncellemelerini burada görebileceksin.")
            Spacer()
        }.padding(.top, 32).navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
    }
}
struct HelpView: View {
    var embedded = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group { if embedded { content } else { NavigationStack { content.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } } } } }
    }
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandLogo(compact: true).frame(maxWidth: .infinity)
                section("Nasıl giriş yaparım?", "Telefon numaranı ve 6 haneli PIN’ini gir. Ardından telefonuna gelen SMS kodunu doğrula. Numaranı 05xx, 5xx veya +90 biçiminde yazabilirsin.")
                section("SMS gelmedi", "Telefon numaranı kontrol et. Bekleme süresi bitince ‘Kodu tekrar gönder’ düğmesini kullan. Yeni kod gönderilince eski kod geçersiz olur.")
                section("PIN’imi unuttum", "PIN sıfırlama hizmeti henüz kullanıma açılmadı. Uygulama şu anda PIN değiştirme veya sıfırlama işlemi yapamaz.")
                section("Favoriler ve taslaklar", "Favoriler ve fotoğraflı ürün taslakları yalnızca bu cihazda, hesaba göre ayrı saklanır. Başka cihaza taşınmaz. Misafir kayıtları giriş yaptığın hesaba otomatik aktarılmaz.")
                section("Hesap ve veriler", "Adın, soyadın, telefonun ve seçtiğin avatar hesap oluşturmak için sunucuya gönderilir. PIN ve SMS kodu cihazda kalıcı saklanmaz. Oturum bilgisi iOS Keychain’de saklanır. Profil → Hesabımı Sil bölümünden hesabını silebilirsin.")
                section("Örnek katalog", "Gösterilen ürünler ve bilet sayıları örnektir. Gerçek ürün yayını, cüzdan, ödeme, bilet ve bildirim hizmetleri henüz açık değildir.")
            }.pagePadding().frame(maxWidth: .infinity)
        }.navigationTitle("Yardım").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(Brand.gray).lineSpacing(4) }
    }
}

struct ConnectionView: View {
    let session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = APIConfiguration.rawURL
    @State private var message: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    #if DEBUG
                    MessageBox(text: "Simülatörde localhost Mac’inizi gösterir. Gerçek iPhone’da Mac’in yerel ağ IP’sini veya HTTPS sunucu adresini kullanın. İki cihaz aynı ağda olmalıdır.")
                    FormField(title: "API adresi", text: $address, keyboard: .URL, identifier: "connection.url")
                    Text("Örnek: http://192.168.1.20:8080/api/v1/").font(.caption.monospaced()).foregroundStyle(Brand.gray)
                    if let message { MessageBox(text: message, isError: true) }
                    PrimaryButton(title: "Bağlantıyı dene ve kaydet", busy: busy) { Task { await save() } }
                    #else
                    MessageBox(text: "Sunucu adresi bu sürümde yapılandırılmamış. Doğru sunucu adresiyle hazırlanmış bir sürüm gereklidir.")
                    #endif
                }.pagePadding().frame(maxWidth: .infinity)
            }.navigationTitle("Bağlantı ayarları").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
    }
    private func save() async {
        #if DEBUG
        guard !busy else { return }; busy = true; message = nil; defer { busy = false }
        do {
            let validated = try APIConfiguration.validate(address)
            _ = try await APIClient(rawURL: validated.absoluteString).avatars()
            try session.changeServer(validated.absoluteString)
            dismiss()
            await session.restore()
        } catch { message = friendlyError(error) }
        #endif
    }
}
