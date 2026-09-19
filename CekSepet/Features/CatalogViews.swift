import SwiftUI

struct MainView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CatalogStore.self) private var catalog
    var onLogin: () -> Void
    @State private var tab = 0
    @State private var addProduct = false
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 1: CatalogView(searchMode: true)
                case 3: ProfileView(onLogin: onLogin)
                default: CatalogView(searchMode: false, onSearch: { tab = 1 })
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 0) {
                tabButton("Ana Sayfa", icon: tab == 0 ? "house.fill" : "house", value: 0)
                tabButton("Ara", icon: "magnifyingglass", value: 1)
                Button { addProduct = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.title2).frame(width: 52, height: 52).background(Brand.yellow, in: Circle())
                        Text("Ekle").font(.caption2)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityIdentifier("tab.add")
                tabButton("Profil", icon: tab == 3 ? "person.fill" : "person", value: 3)
            }.padding(.horizontal, 8).padding(.vertical, 8).background(.white)
                .overlay(alignment: .top) { Rectangle().fill(Brand.separator).frame(height: 1) }
        }
        .sheet(isPresented: $addProduct) { DraftEditor() }
        .alert("Kayıt tamamlanamadı", isPresented: Binding(get: { catalog.errorMessage != nil }, set: { if !$0 { catalog.errorMessage = nil } })) {
            Button("Tamam") { catalog.errorMessage = nil }
        } message: { Text(catalog.errorMessage ?? "") }
    }
    private func tabButton(_ title: String, icon: String, value: Int) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3).foregroundStyle(tab == value ? Brand.yellow : Brand.gray)
                Text(title).font(.caption2).foregroundStyle(tab == value ? Brand.ink : Brand.gray)
            }.frame(maxWidth: .infinity, minHeight: 60)
        }.buttonStyle(.plain).accessibilityAddTraits(tab == value ? .isSelected : []).accessibilityIdentifier("tab.\(value)")
    }
}

struct CatalogView: View {
    var searchMode: Bool
    var onSearch: (() -> Void)?
    @State private var query = ""
    @State private var category = "Tümü"
    @State private var notifications = false
    private var products: [Product] { SampleCatalog.filter(query: query, category: category) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !searchMode {
                        HStack {
                            Label("ÇekSepet", systemImage: "bag.fill").font(.title2.bold()).labelStyle(BrandLabelStyle())
                            Spacer()
                            Button { notifications = true } label: { Image(systemName: "bell").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Bildirimler")
                        }
                    } else { Text("Ara").font(.largeTitle.bold()) }
                    if searchMode {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(Brand.gray)
                            TextField("Ürün veya marka ara", text: $query).submitLabel(.search).autocorrectionDisabled().accessibilityIdentifier("catalog.search")
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Aramayı temizle") }
                        }.padding(14).background(Brand.surface, in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Button(action: { onSearch?() }) {
                            Label("Ürün veya marka ara", systemImage: "magnifyingglass").foregroundStyle(Brand.gray).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(Brand.surface, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SampleCatalog.categories, id: \.self) { item in
                                Button { category = item } label: {
                                    Text(item).font(.subheadline).padding(.horizontal, 17).padding(.vertical, 11)
                                        .background(category == item ? Brand.yellow : .white, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(category == item ? Brand.yellow : Brand.separator))
                                }.buttonStyle(.plain).accessibilityAddTraits(category == item ? .isSelected : [])
                            }
                        }.padding(1)
                    }
                    HStack { Text("Örnek katalog").font(.caption.weight(.semibold)); Spacer(); Text("\(products.count) ürün").font(.caption) }.foregroundStyle(Brand.gray)
                    if products.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "Ürün bulunamadı", detail: "Başka bir kelime veya kategori deneyin.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 24) {
                            ForEach(products) { product in
                                NavigationLink(value: product) { ProductCard(product: product) }.buttonStyle(.plain).accessibilityIdentifier("product.\(product.id)")
                            }
                        }
                    }
                }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
                .sheet(isPresented: $notifications) { NavigationStack { AvailabilityView(kind: .notifications) } }
        }
    }
}
struct BrandLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View { HStack(spacing: 8) { configuration.icon.foregroundStyle(Brand.yellow); configuration.title } }
}
struct ProductCard: View {
    let product: Product
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ProductImage(product: product).aspectRatio(1, contentMode: .fit)
                Image(systemName: "ticket").font(.caption).padding(8).background(Brand.yellow, in: Circle()).padding(8)
            }
            Text(product.title).font(.subheadline).lineLimit(1)
            Text(product.brand).font(.caption).foregroundStyle(Brand.gray)
            TicketProgress(product: product)
        }.accessibilityElement(children: .combine)
    }
}
struct ProductImage: View {
    let product: Product
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Brand.separator)
            .overlay { Image(systemName: "photo").font(.title3).foregroundStyle(Brand.gray) }.accessibilityLabel("Ürün görseli bulunmuyor")
    }
}
struct TicketProgress: View {
    let product: Product
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geometry in
                Capsule().fill(Brand.separator).overlay(alignment: .leading) {
                    Capsule().fill(Brand.yellow).frame(width: geometry.size.width * product.fraction)
                }
            }.frame(height: 8)
            Label(product.ticketLabel, systemImage: "ticket").font(.caption2).foregroundStyle(Brand.gray)
        }.accessibilityLabel("Örnek bilet ilerlemesi \(product.ticketProgress), hedef \(product.ticketGoal)")
    }
}
struct ProductDetailView: View {
    let product: Product
    @Environment(CatalogStore.self) private var catalog
    @State private var showInfo = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProductImage(product: product).frame(height: 320)
                HStack {
                    VStack(alignment: .leading, spacing: 6) { Text(product.title).font(.title2.bold()); Text(product.brand).foregroundStyle(Brand.gray) }
                    Spacer()
                    Button { catalog.toggle(product) } label: {
                        Image(systemName: catalog.favorites.contains(product.id) ? "heart.fill" : "heart").font(.title2).foregroundStyle(Brand.ink).frame(width: 44, height: 44)
                    }.accessibilityLabel(catalog.favorites.contains(product.id) ? "Favorilerden çıkar" : "Favorilere ekle").accessibilityIdentifier("product.favorite")
                }
                TicketProgress(product: product)
                Label(product.category, systemImage: "square.grid.2x2").font(.subheadline)
                Text("Ürün hakkında").font(.headline)
                Text("Bu ürün, uygulamanın örnek kataloğundadır. Ürün açıklaması ve gerçek görseller henüz yayınlanmadı.").font(.subheadline).foregroundStyle(Brand.gray)
                MessageBox(text: "Bilet sayıları örnektir. Bu ürün için çekilişe katılım ve ödeme şu anda kullanılamıyor.")
                ShareLink(item: "ÇekSepet örnek kataloğunda \(product.title) — \(product.brand)") { Label("Paylaş", systemImage: "square.and.arrow.up") }.font(.subheadline)
            }.pagePadding().frame(maxWidth: .infinity)
        }.navigationTitle("Ürün").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Katılım bilgisi") { showInfo = true }.padding(16).background(.white)
            }.sheet(isPresented: $showInfo) { NavigationStack { AvailabilityView(kind: .tickets) } }
    }
}
struct FavoritesView: View {
    @Environment(CatalogStore.self) private var catalog
    var body: some View {
        ScrollView {
            if catalog.favorites.isEmpty { EmptyState(icon: "heart", title: "Henüz favorin yok", detail: "Ürün detayındaki kalbe dokunarak favorilerini burada biriktir.") }
            else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 24) {
                    ForEach(SampleCatalog.products.filter { catalog.favorites.contains($0.id) }) { product in
                        NavigationLink { ProductDetailView(product: product) } label: { ProductCard(product: product) }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
        }.navigationTitle("Favorilerim").navigationBarTitleDisplayMode(.inline)
    }
}
