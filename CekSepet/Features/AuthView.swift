import SwiftUI

struct AuthView: View {
    @State private var flow: AuthFlow
    let close: () -> Void
    let switchMode: () -> Void
    let browse: () -> Void
    @State private var showHelp = false
    @State private var showConnection = false
    @State private var restartConfirmation = false
    init(mode: AuthFlow.Mode, session: SessionStore, close: @escaping () -> Void, switchMode: @escaping () -> Void, browse: @escaping () -> Void) {
        _flow = State(initialValue: AuthFlow(mode: mode, session: session))
        self.close = close; self.switchMode = switchMode; self.browse = browse
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if flow.mode == .login && flow.step == .details { BrandLogo().padding(.top, 24).padding(.bottom, 12) }
                    switch flow.step {
                    case .details: details
                    case .avatar: avatarPicker
                    case .otp: otpContent
                    }
                    if let message = flow.message { MessageBox(text: message, isError: true).accessibilityIdentifier("auth.error") }
                    if flow.step != .otp {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            let remaining = max(0, Int(ceil(flow.retryAt.timeIntervalSince(timeline.date))))
                            PrimaryButton(title: remaining > 0 ? "\(remaining) sn sonra tekrar dene" : (flow.step == .avatar || flow.mode == .register ? "Devam et" : "Giriş Yap"),
                                          busy: flow.isBusy, enabled: remaining == 0 && (flow.step != .avatar || flow.selectedAvatar != nil)) {
                                Task { if flow.step == .avatar { await flow.submitAvatar() } else { await flow.submitDetails() } }
                            }.accessibilityIdentifier("auth.submit")
                        }
                    }
                    if flow.mode == .register { StepDots(index: flow.step == .details ? 0 : flow.step == .avatar ? 1 : 2) }
                    if flow.step == .details {
                        Button(flow.mode == .login ? "Bir hesabın yok mu? Kayıt Ol" : "Zaten hesabın var mı? Giriş Yap", action: switchMode)
                            .font(.subheadline.weight(.semibold)).frame(minHeight: 44).disabled(flow.isBusy).accessibilityIdentifier("auth.switch")
                        if flow.mode == .login {
                            Button("PIN’imi unuttum") { showHelp = true }.font(.subheadline).foregroundStyle(Brand.gray)
                            Button("Örnek kataloğu keşfet", action: browse).font(.subheadline).frame(minHeight: 44).disabled(flow.isBusy).accessibilityIdentifier("auth.browse")
                        }
                        #if DEBUG
                        Button { showConnection = true } label: { Label("Bağlantı ayarları", systemImage: "network") }
                            .font(.caption).foregroundStyle(Brand.gray).disabled(flow.isBusy)
                        #endif
                    }
                }.pagePadding().frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).dismissKeyboardToolbar()
                .navigationTitle(flow.mode == .register ? "KAYIT OL" : flow.step == .otp ? "SMS DOĞRULAMA" : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if flow.mode == .register || flow.step != .details {
                            Button { if flow.step == .details { close() } else { restartConfirmation = true } } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                                .disabled(flow.isBusy).accessibilityLabel("Geri")
                        }
                    }
                }
                .confirmationDialog("Bu işlemi bırakıp yeniden başlamak istiyor musunuz?", isPresented: $restartConfirmation, titleVisibility: .visible) {
                    Button("Yeniden başla", role: .destructive) { flow.restart() }
                }
                .sheet(isPresented: $showHelp) { HelpView() }
                .sheet(isPresented: $showConnection) { ConnectionView(session: flow.session) }
                .onDisappear { flow.abandon() }
        }
    }
    private var details: some View {
        VStack(spacing: 16) {
            if flow.mode == .register {
                Text("Aramıza hoş geldin!").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                Text("Hesabını oluştur, fırsatları keşfet.").font(.subheadline).foregroundStyle(Brand.gray).frame(maxWidth: .infinity, alignment: .leading)
                FormField(title: "İsim", text: $flow.firstName, contentType: .givenName, error: flow.fieldErrors["firstName"], identifier: "auth.firstName")
                FormField(title: "Soyisim", text: $flow.lastName, contentType: .familyName, error: flow.fieldErrors["lastName"], identifier: "auth.lastName")
            }
            FormField(title: "Telefon Numarası", text: $flow.phone, keyboard: .phonePad, contentType: .telephoneNumber, error: flow.fieldErrors["phone"], identifier: "auth.phone")
            FormField(title: flow.mode == .register ? "6 haneli PIN belirle" : "6 haneli PIN", text: $flow.pin, secure: true, keyboard: .numberPad, contentType: .password, error: flow.fieldErrors["pin"], identifier: "auth.pin")
                .onChange(of: flow.pin) { _, value in flow.pin = InputValidation.digits(value) }
            if flow.mode == .register { Text("Telefonunu bir sonraki adımda SMS ile doğrulayacağız.").font(.caption).foregroundStyle(Brand.gray) }
        }.disabled(flow.isBusy)
    }
    private var avatarPicker: some View {
        VStack(spacing: 22) {
            Text("Kendine bir avatar seç").font(.title2.bold())
            Text("ÇekSepet’te seni bu avatar temsil edecek. Kullanıcı adını senin için oluşturacağız.").font(.subheadline).foregroundStyle(Brand.gray).multilineTextAlignment(.center)
            if flow.loadingAvatars { ProgressView().padding(40) }
            if let error = flow.avatarError {
                MessageBox(text: error, isError: true)
                Button("Tekrar dene") { Task { await flow.loadAvatars() } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                ForEach(flow.avatars) { avatar in
                    Button { flow.selectedAvatar = avatar.id } label: {
                        VStack(spacing: 8) {
                            AvatarView(id: avatar.id).padding(5)
                                .overlay(Circle().stroke(flow.selectedAvatar == avatar.id ? Brand.yellow : .clear, lineWidth: 3))
                            Text(avatar.name).font(.caption)
                        }
                    }.buttonStyle(.plain).disabled(flow.isBusy)
                        .accessibilityLabel(avatar.name).accessibilityAddTraits(flow.selectedAvatar == avatar.id ? .isSelected : [])
                        .accessibilityIdentifier("avatar.\(avatar.id)")
                }
            }
        }
    }
    private var otpContent: some View {
        VStack(spacing: 22) {
            Image(systemName: "message.badge.filled.fill").font(.system(size: 54)).foregroundStyle(Brand.yellow).padding(.top, 20)
            Text("Telefonunu doğrula").font(.title2.bold())
            if !flow.username.isEmpty { Text("Kullanıcı adın: \(flow.username)").font(.subheadline).foregroundStyle(Brand.green) }
            Text("\(flow.maskedPhone) numarasına gönderilen 6 haneli SMS kodunu gir.").multilineTextAlignment(.center).font(.subheadline).foregroundStyle(Brand.gray)
            FormField(title: "SMS doğrulama kodu", text: $flow.otp, keyboard: .numberPad, contentType: .oneTimeCode, error: flow.fieldErrors["otpCode"], identifier: "auth.otp")
                .onChange(of: flow.otp) { _, value in flow.otp = InputValidation.digits(value) }.disabled(flow.isBusy)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let expires = max(0, Int(ceil(flow.otpExpiresAt.timeIntervalSince(timeline.date))))
                let retry = max(0, Int(ceil(flow.retryAt.timeIntervalSince(timeline.date))))
                VStack(spacing: 18) {
                    Text(expires > 0 ? "Kodun geçerlilik süresi: \(expires / 60):\(String(format: "%02d", expires % 60))" : "Kodun süresi doldu. Yeni bir kod isteyin.")
                        .font(.caption).foregroundStyle(expires > 0 ? Brand.gray : .red)
                    PrimaryButton(title: "Doğrula", busy: flow.isBusy, enabled: InputValidation.sixDigits(flow.otp) && expires > 0 && !flow.verifyLocked) {
                        Task { await flow.verify() }
                    }.accessibilityIdentifier("auth.verify")
                    Button(retry > 0 ? "Tekrar gönder (\(retry) sn)" : "Kodu tekrar gönder") { Task { await flow.resend() } }
                        .disabled(retry > 0 || flow.isBusy).font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("auth.resend")
                }
            }
            #if DEBUG
            if let code = flow.debugCode { Text("Geliştirme SMS kodu: \(code)").font(.caption.monospaced()).foregroundStyle(Brand.gray).accessibilityIdentifier("auth.debugCode") }
            #endif
        }
    }
}
