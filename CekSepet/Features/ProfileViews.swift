import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CatalogStore.self) private var catalog
    var onLogin: () -> Void
    @State private var deleteAccount = false
    @State private var logout = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Text("Profil").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    if let user = session.user {
                        AvatarView(id: user.avatarId).frame(width: 96, height: 96)
                        VStack(spacing: 6) {
                            Text(user.displayName).font(.title2.bold())
                            Text(user.username).font(.subheadline).foregroundStyle(Brand.gray)
                            if let phone = user.phone { Text(phone).font(.caption).foregroundStyle(Brand.gray) }
                        }
                    } else {
                        EmptyState(icon: "person.crop.circle", title: "ÇekSepet’e hoş geldin", detail: "Örnek kataloğu keşfediyorsun. Kendi hesabın için giriş yapabilirsin.")
                        PrimaryButton(title: "Giriş Yap", action: onLogin)
                    }
                    if session.isBusy { ProgressView() }
                    if let message = session.message { MessageBox(text: message, isError: true) }
                    VStack(spacing: 10) {
                        NavigationLink { FavoritesView() } label: { ProfileRow(title: "Favorilerim", icon: "heart", detail: "\(catalog.favorites.count)") }
                        NavigationLink { DraftListView() } label: { ProfileRow(title: "Ürün taslaklarım", icon: "square.and.pencil", detail: "\(catalog.drafts.count)") }
                        NavigationLink { AvailabilityView(kind: .wallet) } label: { ProfileRow(title: "Cüzdan", icon: "wallet.bifold") }
                        NavigationLink { AvailabilityView(kind: .tickets) } label: { ProfileRow(title: "Biletlerim", icon: "ticket") }
                        if session.user != nil {
                            NavigationLink { CommunityView() } label: { ProfileRow(title: "Topluluk", icon: "person.2") }
                        }
                        NavigationLink { HelpView(embedded: true) } label: { ProfileRow(title: "Yardım ve uygulama bilgileri", icon: "questionmark.circle") }
                    }.buttonStyle(.plain)
                    if session.user != nil {
                        Button("Çıkış Yap") { logout = true }.font(.headline).frame(minHeight: 44).disabled(session.isBusy).accessibilityIdentifier("profile.logout")
                        Button("Hesabımı Sil", role: .destructive) { deleteAccount = true }.font(.subheadline).frame(minHeight: 44).disabled(session.isBusy).accessibilityIdentifier("profile.delete")
                    }
                    Text("ÇekSepet · 1.0.0").font(.caption2).foregroundStyle(Brand.gray)
                }.pagePadding().frame(maxWidth: .infinity)
            }.refreshable { await session.refresh() }
                .toolbar(.hidden, for: .navigationBar)
                .confirmationDialog("Oturumun kapatılsın mı?", isPresented: $logout, titleVisibility: .visible) {
                    Button("Çıkış Yap", role: .destructive) { Task { await session.logout() } }
                }
                .sheet(isPresented: $deleteAccount) { DeleteAccountView() }
        }
    }
}
struct ProfileRow: View {
    let title: String
    let icon: String
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 26)
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(Brand.gray) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.gray)
        }.padding(17).background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct DeleteAccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var pin = ""
    @State private var message: String?
    @State private var fields: [String: String] = [:]
    @State private var confirm = false
    @State private var retryAt = Date.distantPast
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    EmptyState(icon: "person.crop.circle.badge.minus", title: "Hesabını sil", detail: "Bu işlem geri alınamaz. Hesabın ve tüm sunucu oturumların silinir. Bu hesaba ait cihazdaki favoriler ve taslaklar da kaldırılır.")
                    FormField(title: "Kullanıcı adı", text: $username, error: fields["username"], identifier: "delete.username")
                    FormField(title: "6 haneli PIN", text: $pin, secure: true, keyboard: .numberPad, error: fields["pin"], identifier: "delete.pin")
                        .onChange(of: pin) { _, value in pin = InputValidation.digits(value) }
                    if let message { MessageBox(text: message, isError: true).accessibilityIdentifier("delete.error") }
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let retry = max(0, Int(ceil(retryAt.timeIntervalSince(timeline.date))))
                        PrimaryButton(title: retry > 0 ? "\(retry) sn sonra tekrar dene" : "Hesabımı kalıcı olarak sil", busy: session.isBusy,
                                      enabled: !username.trimmingCharacters(in: .whitespaces).isEmpty && InputValidation.sixDigits(pin) && retry == 0, destructive: true) { confirm = true }
                            .accessibilityIdentifier("delete.submit")
                    }
                }.pagePadding().frame(maxWidth: .infinity)
            }.dismissKeyboardToolbar().navigationTitle("Hesabı sil").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() }.disabled(session.isBusy) } }
                .interactiveDismissDisabled(session.isBusy)
                .confirmationDialog("Hesabın kalıcı olarak silinecek.", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Evet, hesabımı sil", role: .destructive) { Task { await delete() } }
                }
        }
    }
    private func delete() async {
        message = nil; fields = [:]
        do {
            // Capture this archive before the root switches account scope on sign out.
            let scope = (session.api.baseURL?.absoluteString ?? "unconfigured") + "|" + (session.user?.id ?? "guest")
            let accountData = CatalogStore(); accountData.activate(scope: scope)
            try await session.delete(username: username.trimmingCharacters(in: .whitespaces), pin: pin)
            try accountData.eraseCurrentAccount()
            pin = ""; dismiss()
        } catch {
            message = friendlyError(error)
            if let error = error as? APIError {
                fields = error.fieldErrors ?? [:]
                if let seconds = error.retryAfter { retryAt = Date().addingTimeInterval(TimeInterval(seconds)) }
            }
        }
    }
}

struct CommunityView: View {
    @Environment(SessionStore.self) private var session
    @State private var users: [APIUser] = []
    @State private var total = 0
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(users) { user in
                    HStack(spacing: 14) {
                        AvatarView(id: user.avatarId).frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 4) { Text(user.displayName).font(.headline); Text(user.username).font(.caption).foregroundStyle(Brand.gray) }
                        Spacer()
                    }
                }
                if let message { MessageBox(text: message, isError: true); Button("Tekrar dene") { Task { await load() } } }
                if busy { ProgressView() }
                if !busy && users.isEmpty && message == nil { EmptyState(icon: "person.2", title: "Topluluk henüz boş", detail: "Yeni üyeler burada görünecek.") }
                if users.count < total && !busy { Button("Daha fazla göster") { Task { await load() } } }
            }.pagePadding().frame(maxWidth: .infinity)
        }.navigationTitle("Topluluk").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .task { if users.isEmpty { await load() } }
            .refreshable { guard !busy else { return }; users = []; total = 0; await load() }
    }
    private func load() async {
        guard !busy else { return }; busy = true; message = nil; defer { busy = false }
        do {
            let response = try await session.api.users(offset: users.count)
            let known = Set(users.map(\.id)); users += response.users.filter { !known.contains($0.id) }; total = response.total
        } catch { if !(error is CancellationError) { message = friendlyError(error) } }
    }
}
