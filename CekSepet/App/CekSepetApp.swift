import SwiftUI

@main
struct CekSepetApp: App {
    @State private var session: SessionStore
    @State private var catalog = CatalogStore()
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-reset") {
            UserDefaults.standard.removeObject(forKey: "onboardingComplete")
            UserDefaults.standard.removeObject(forKey: "developmentAPIURL")
            if let url = try? APIConfiguration.validate(APIConfiguration.rawURL) { try? KeychainStore(environment: url.absoluteString).remove() }
        }
        #endif
        _session = State(initialValue: SessionStore())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(session).environment(catalog)
                .tint(Brand.ink).foregroundStyle(Brand.ink).preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "tr_TR"))
        }
    }
}

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var mode: AuthFlow.Mode = .login
    @State private var guest = false
    @State private var settings = false
    private var scope: String { (session.api.baseURL?.absoluteString ?? "unconfigured") + "|" + (session.user?.id ?? "guest") }
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            switch session.phase {
            case .restoring:
                VStack(spacing: 28) { BrandLogo(); ProgressView("Oturum kontrol ediliyor…").font(.caption) }
            case .unavailable:
                VStack(spacing: 20) {
                    BrandLogo(compact: true)
                    MessageBox(text: session.message ?? "Oturum doğrulanamadı.", isError: true)
                    PrimaryButton(title: "Tekrar dene", busy: session.isBusy) { Task { await session.restore() } }
                    #if DEBUG
                    Button("Bağlantı ayarları") { settings = true }
                    #endif
                }.pagePadding()
            case .signedIn:
                MainView(onLogin: {}).id(scope)
            case .signedOut:
                if !onboardingComplete {
                    OnboardingView { register in mode = register ? .register : .login; onboardingComplete = true }
                } else if guest {
                    MainView(onLogin: { guest = false; mode = .login }).id(scope)
                } else {
                    AuthView(mode: mode, session: session, close: { mode = .login }, switchMode: { mode = mode == .login ? .register : .login }, browse: { guest = true })
                        .id("\(mode)-\(session.api.baseURL?.absoluteString ?? "")")
                }
            }
            // Hide personal data and OTP/PIN screens in app-switcher snapshots.
            if scenePhase != .active {
                Color.white.ignoresSafeArea().overlay { BrandLogo() }.accessibilityHidden(true)
            }
        }
        .sheet(isPresented: $settings) { ConnectionView(session: session) }
        .task { await session.restore() }
        .onChange(of: scope, initial: true) { _, new in catalog.activate(scope: new) }
        .onChange(of: session.phase) { old, new in
            if old == .signedIn && new == .signedOut { guest = false; mode = .login }
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active && session.phase == .signedIn { Task { await session.refresh() } }
        }
    }
}
