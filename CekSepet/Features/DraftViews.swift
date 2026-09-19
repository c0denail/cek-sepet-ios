import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO

struct DraftListView: View {
    @Environment(CatalogStore.self) private var catalog
    @State private var selected: ProductDraft?
    @State private var deleting: ProductDraft?
    @State private var newDraft = false
    var body: some View {
        Group {
            if catalog.drafts.isEmpty {
                EmptyState(icon: "square.and.pencil", title: "İlk ürününü hazırla", detail: "Fotoğraflar ve ürün bilgileri bu cihazda taslak olarak saklanır.")
            } else {
                List {
                    ForEach(catalog.drafts) { draft in
                        Button { selected = draft } label: {
                            HStack(spacing: 14) {
                                if let data = draft.photos.first, let image = UIImage(data: data) {
                                    Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                                } else { Image(systemName: "photo").frame(width: 64, height: 64).background(Brand.separator, in: RoundedRectangle(cornerRadius: 8)) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(draft.title).font(.headline)
                                    Text("\(draft.category) · Cihazda taslak").font(.caption).foregroundStyle(Brand.gray)
                                    Text(draft.updatedAt, style: .date).font(.caption2).foregroundStyle(Brand.gray)
                                }
                            }.padding(.vertical, 4)
                        }.buttonStyle(.plain).swipeActions { Button("Sil", role: .destructive) { deleting = draft } }
                    }
                }.listStyle(.plain)
            }
        }.navigationTitle("Ürün taslaklarım").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { newDraft = true } label: { Image(systemName: "plus") }.accessibilityLabel("Yeni ürün taslağı") } }
            .sheet(item: $selected) { DraftEditor(existing: $0) }
            .sheet(isPresented: $newDraft) { DraftEditor() }
            .confirmationDialog("Bu taslak silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Taslağı sil", role: .destructive) { if let deleting { catalog.remove(deleting) }; deleting = nil }
            }
    }
}

struct DraftEditor: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProductDraft
    private let original: ProductDraft
    @State private var selections: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var camera = false
    @State private var message: String?
    @State private var errors: [String: String] = [:]
    @State private var discard = false
    @State private var saved = false
    @State private var photoTask: Task<Void, Never>?
    init(existing: ProductDraft? = nil) {
        let draft = existing ?? ProductDraft()
        original = draft; _draft = State(initialValue: draft)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MessageBox(text: "Ürününü hazırla. Taslak bu cihazda saklanır; henüz yayınlanmaz.")
                    Text("Fotoğraflar (\(draft.photos.count)/4)").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(draft.photos.enumerated()), id: \.offset) { index, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image).resizable().scaledToFill().frame(width: 90, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button { draft.photos.remove(at: index) } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, Brand.ink).font(.title3).padding(4) }.accessibilityLabel("\(index + 1). fotoğrafı kaldır")
                                        }
                                }
                            }
                            if draft.photos.count < 4 {
                                PhotosPicker(selection: $selections, maxSelectionCount: 4 - draft.photos.count, matching: .images) {
                                    VStack { Image(systemName: "plus").font(.title); Text("Fotoğraf").font(.caption) }
                                        .frame(width: 90, height: 100).background(Brand.separator, in: RoundedRectangle(cornerRadius: 8))
                                }.disabled(importing).accessibilityLabel("Galeriden fotoğraf ekle")
                            }
                        }.padding(.vertical, 4)
                    }
                    HStack {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { Task { await openCamera() } } label: { Label("Fotoğraf çek", systemImage: "camera") }.disabled(draft.photos.count >= 4 || importing)
                        }
                        if importing { ProgressView("Fotoğraf hazırlanıyor…").font(.caption) }
                    }
                    FormField(title: "Başlık", text: $draft.title, error: errors["title"], identifier: "draft.title")
                    FormField(title: "Marka", text: $draft.brand, error: errors["brand"], identifier: "draft.brand")
                    VStack(alignment: .leading) {
                        Text("Kategori").font(.subheadline.weight(.medium))
                        Picker("Kategori", selection: $draft.category) { ForEach(SampleCatalog.categories.dropFirst(), id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Açıklama").font(.subheadline.weight(.medium))
                        TextEditor(text: $draft.description).frame(minHeight: 130).padding(8).scrollContentBackground(.hidden)
                            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("draft.description")
                        if let error = errors["description"] { Text(error).font(.caption).foregroundStyle(.red) }
                    }
                    FormField(title: "Toplam bilet hedefi", text: $draft.ticketGoal, keyboard: .numberPad, error: errors["ticketGoal"], identifier: "draft.goal")
                        .onChange(of: draft.ticketGoal) { _, value in draft.ticketGoal = InputValidation.digits(value, limit: 7) }
                    if let message { MessageBox(text: message, isError: true) }
                    PrimaryButton(title: "Taslağı kaydet", enabled: !importing) { save() }.accessibilityIdentifier("draft.save")
                }.pagePadding().frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).dismissKeyboardToolbar()
                .navigationTitle("Ürün Ekle").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { if draft != original { discard = true } else { dismiss() } } } }
                .interactiveDismissDisabled(draft != original || importing)
                .confirmationDialog("Kaydedilmemiş değişiklikler silinsin mi?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Değişiklikleri sil", role: .destructive) { dismiss() }
                }
                .alert("Taslak kaydedildi", isPresented: $saved) { Button("Tamam") { dismiss() } } message: { Text("Ürününü Profil → Ürün taslaklarım bölümünden düzenleyebilirsin.") }
                .fullScreenCover(isPresented: $camera) {
                    CameraPicker { image in
                        camera = false
                        if let image, let data = image.jpegData(compressionQuality: 0.85) { appendImage(data) }
                    }.ignoresSafeArea()
                }
                .onChange(of: selections) { _, items in
                    guard !items.isEmpty else { return }
                    photoTask?.cancel()
                    photoTask = Task { await importPhotos(items) }
                }
                .onDisappear { photoTask?.cancel() }
        }
    }
    private func save() {
        errors = [:]; message = nil
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !(3...100).contains(draft.title.count) { errors["title"] = "Başlık 3–100 karakter olmalıdır." }
        if draft.brand.count > 80 { errors["brand"] = "Marka en fazla 80 karakter olabilir." }
        if !(10...2000).contains(draft.description.count) { errors["description"] = "Açıklama 10–2000 karakter olmalıdır." }
        if let count = Int(draft.ticketGoal), (1...1_000_000).contains(count) {} else { errors["ticketGoal"] = "1–1.000.000 arasında bilet hedefi girin." }
        guard errors.isEmpty else { message = "İşaretli alanları kontrol edin."; return }
        do { try catalog.save(draft); saved = true }
        catch { message = "Taslak kaydedilemedi. Cihazda boş alan olduğundan emin olun." }
    }
    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        importing = true; message = nil
        defer { importing = false; selections = [] }
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ClientError.invalidResponse }
                try Task.checkCancellation()
                appendImage(data)
            } catch is CancellationError { return }
            catch { message = "Fotoğraf alınamadı. Galeriden başka bir görsel seçmeyi deneyin." }
        }
    }
    private func appendImage(_ data: Data) {
        guard draft.photos.count < 4 else { return }
        guard data.count <= 50_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8) else {
            message = "Fotoğraf işlenemedi. 50 MB’tan küçük bir görsel seçin."; return
        }
        draft.photos.append(jpeg)
    }
    @MainActor private func openCamera() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var granted = status == .authorized
        if status == .notDetermined { granted = await requestCamera() }
        if granted { camera = true }
        else { message = "Kamera izni kapalı. iPhone Ayarlar → ÇekSepet bölümünden kamera erişimini açabilirsiniz." }
    }
    private func requestCamera() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { onImage(info[.originalImage] as? UIImage) }
    }
}
