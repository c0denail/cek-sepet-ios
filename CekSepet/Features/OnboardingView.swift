import SwiftUI

struct OnboardingView: View {
    var onComplete: (Bool) -> Void
    @State private var page = 0
    private let titles = ["İSTER ÇEKİLİŞE KATIL", "İSTER ÇEKİLİŞ DÜZENLE", "FIRSATLARI KAÇIRMA!"]
    private let details = ["ÇekSepet ile ürünleri keşfet, favorilerini seç ve fırsatları takip et.", "Kullanmadığın ürünler için fotoğraflı taslaklar hazırla.", "ÇekSepet’in fırsatlar dünyasına şimdi katıl."]
    var body: some View {
        GeometryReader { geometry in
            VStack {
                TabView(selection: $page) {
                    ForEach(0..<3) { i in
                        ScrollView {
                            VStack(spacing: 20) {
                                Image("onboarding_0\(i + 1)_illustration").resizable().scaledToFit()
                                    .frame(height: min(geometry.size.height * 0.43, 375)).accessibilityHidden(true)
                                Text(titles[i]).font(.system(.title2, weight: .bold)).multilineTextAlignment(.center)
                                Text(details[i]).font(.subheadline).foregroundStyle(Brand.gray).multilineTextAlignment(.center).lineSpacing(5)
                            }.padding(.horizontal, 24).padding(.top, max(24, geometry.size.height * 0.08))
                                .frame(maxWidth: 600).frame(maxWidth: .infinity)
                        }.tag(i)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never))
                VStack(spacing: 24) {
                    if page == 2 {
                        PrimaryButton(title: "Hemen Başla") { onComplete(true) }.accessibilityIdentifier("onboarding.start")
                    }
                    HStack {
                        Button("Geç") { onComplete(false) }.foregroundStyle(Brand.gray).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("onboarding.skip")
                        Spacer(); StepDots(index: page); Spacer()
                        Button { if page < 2 { withAnimation { page += 1 } } else { onComplete(true) } } label: {
                            Image(systemName: "arrow.right").font(.title3).frame(width: 48, height: 48)
                                .background(Brand.yellow, in: Circle())
                        }.accessibilityLabel("Sonraki").accessibilityIdentifier("onboarding.next")
                    }
                }.padding(24).frame(maxWidth: 650)
            }
        }.foregroundStyle(Brand.ink).background(.white)
    }
}
