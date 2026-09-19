import Foundation
import Observation
import CryptoKit

struct Product: Identifiable, Hashable {
    let id: String
    let title: String
    let brand: String
    let category: String
    let ticketProgress: Int
    let ticketGoal: Int
    let symbol: String
    var fraction: Double { ticketGoal > 0 ? min(1, max(0, Double(ticketProgress) / Double(ticketGoal))) : 0 }
    var ticketLabel: String { "\(ticketProgress)/\(ticketGoal)" }
}
enum SampleCatalog {
    static let categories = ["Tümü", "Giyim", "Elektronik", "Ev", "Spor"]
    // Matches Android MockData.kt. No catalog or ticket endpoints exist in this backend.
    static let products: [Product] = [
        .init(id: "prod-1", title: "Iphone 11", brand: "Apple", category: "Elektronik", ticketProgress: 1765, ticketGoal: 2000, symbol: "iphone"),
        .init(id: "prod-2", title: "Macbook Air M1", brand: "Apple", category: "Elektronik", ticketProgress: 1765, ticketGoal: 2000, symbol: "laptopcomputer"),
        .init(id: "prod-3", title: "Zara Kadın M Kazak", brand: "Zara", category: "Giyim", ticketProgress: 1765, ticketGoal: 2000, symbol: "tshirt"),
        .init(id: "prod-4", title: "Nike Air Max", brand: "Nike", category: "Spor", ticketProgress: 890, ticketGoal: 2000, symbol: "shoe"),
        .init(id: "prod-5", title: "Samsung Galaxy S21", brand: "Samsung", category: "Elektronik", ticketProgress: 1200, ticketGoal: 2000, symbol: "smartphone"),
        .init(id: "prod-6", title: "H&M Erkek Ceket", brand: "H&M", category: "Giyim", ticketProgress: 450, ticketGoal: 2000, symbol: "jacket")
    ]
    static func filter(query: String, category: String) -> [Product] {
        products.filter { product in
            (category == "Tümü" || product.category == category) &&
            (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
             "\(product.title) \(product.brand) \(product.category)".range(of: query.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")) != nil)
        }
    }
}
struct ProductDraft: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var brand = ""
    var category = "Elektronik"
    var description = ""
    var ticketGoal = ""
    var photos: [Data] = []
    var updatedAt = Date()
}

@MainActor @Observable
final class CatalogStore {
    private struct Archive: Codable {
        var favorites: Set<String> = []
        var drafts: [ProductDraft] = []
    }
    private(set) var favorites: Set<String> = []
    private(set) var drafts: [ProductDraft] = []
    var errorMessage: String?
    @ObservationIgnored private var file: URL?
    @ObservationIgnored private var loadFailed = false
    @ObservationIgnored private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("CekSepet", isDirectory: true)
    }
    func activate(scope: String) {
        favorites = []; drafts = []; errorMessage = nil; loadFailed = false
        let key = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        file = directory.appendingPathComponent(key + ".json")
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
            favorites = archive.favorites; drafts = archive.drafts
        } catch {
            loadFailed = true
            errorMessage = "Cihazdaki kayıtlar okunamadı. Mevcut dosyalar korunuyor. Uygulamayı yeniden açmayı deneyin."
        }
    }
    func toggle(_ product: Product) {
        var updated = favorites
        if updated.contains(product.id) { updated.remove(product.id) } else { updated.insert(product.id) }
        do { try persist(favorites: updated, drafts: drafts); favorites = updated }
        catch { errorMessage = friendlyError(error) }
    }
    func save(_ draft: ProductDraft) throws {
        var copy = draft; copy.updatedAt = Date()
        var updated = drafts.filter { $0.id != draft.id }; updated.insert(copy, at: 0)
        try persist(favorites: favorites, drafts: updated); drafts = updated
    }
    func remove(_ draft: ProductDraft) {
        let updated = drafts.filter { $0.id != draft.id }
        do { try persist(favorites: favorites, drafts: updated); drafts = updated }
        catch { errorMessage = friendlyError(error) }
    }
    func eraseCurrentAccount() throws {
        if let file, FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        favorites = []; drafts = []
    }
    private func persist(favorites: Set<String>, drafts: [ProductDraft]) throws {
        guard let file, !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Archive(favorites: favorites, drafts: drafts))
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        var excluded = file
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        errorMessage = nil
    }
}
