import SwiftUI

enum Brand {
    static let yellow = Color(hex: 0xFFCB0A)
    static let ink = Color(hex: 0x232323)
    static let gray = Color(hex: 0x848484)
    static let separator = Color(hex: 0xE8E8E8)
    static let green = Color(hex: 0x2E7D32)
    static let surface = Color(hex: 0xF7F7F7)
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
struct BrandLogo: View {
    var compact = false
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "bag.fill").font(.system(size: compact ? 34 : 66)).foregroundStyle(Brand.yellow)
            Text("ÇekSepet").font(.system(size: compact ? 24 : 36, weight: .bold, design: .rounded)).foregroundStyle(Brand.yellow)
            if !compact { Text("sepetinde fırsat var").font(.subheadline).foregroundStyle(Brand.green) }
        }.accessibilityElement(children: .combine)
    }
}
struct PrimaryButton: View {
    let title: String
    var busy = false
    var enabled = true
    var destructive = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(destructive ? .white : Brand.ink) }
                Text(title).font(.headline)
            }.frame(maxWidth: .infinity).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(destructive ? .white : Brand.ink)
        .background(destructive ? Color.red : Brand.yellow, in: RoundedRectangle(cornerRadius: 8))
        .opacity(enabled && !busy ? 1 : 0.55).disabled(!enabled || busy)
    }
}
struct FormField: View {
    let title: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var error: String?
    var identifier = ""
    @State private var reveal = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            HStack {
                Group {
                    if secure && !reveal { SecureField(title, text: $text) }
                    else { TextField(title, text: $text) }
                }
                .keyboardType(keyboard).textContentType(contentType)
                .textInputAutocapitalization(contentType == .givenName || contentType == .familyName ? .words : .never)
                .autocorrectionDisabled().accessibilityIdentifier(identifier)
                if secure {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(Brand.gray).frame(width: 32, height: 36)
                    }.accessibilityLabel(reveal ? "PIN'i gizle" : "PIN'i göster")
                }
            }.padding(.horizontal, 14).frame(minHeight: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(error == nil ? Brand.separator : .red, lineWidth: 1))
            if let error { Text(error).font(.caption).foregroundStyle(.red).accessibilityIdentifier(identifier + ".error") }
        }
    }
}
struct MessageBox: View {
    let text: String
    var isError = false
    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "info.circle")
            .font(.subheadline).foregroundStyle(isError ? .red : Brand.gray)
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(isError ? Color.red.opacity(0.06) : Brand.surface, in: RoundedRectangle(cornerRadius: 10))
            .fixedSize(horizontal: false, vertical: true)
    }
}
struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 44, weight: .light)).foregroundStyle(Brand.yellow)
                .frame(width: 96, height: 96).background(Brand.surface, in: Circle())
            Text(title).font(.title3.bold())
            Text(detail).font(.subheadline).foregroundStyle(Brand.gray).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28)
    }
}
struct StepDots: View {
    let index: Int
    var body: some View {
        HStack(spacing: 10) { ForEach(0..<3) { i in Circle().fill(i == index ? Color(hex: 0x34C759) : Brand.separator).frame(width: 9, height: 9) } }
            .accessibilityLabel("Adım \(index + 1), 3 adım")
    }
}

// Native rendition of the exact eight SVGs in backend/internal/httpapi/avatars.go.
// The live catalog controls IDs and labels; this avoids a web view or third-party SVG runtime.
struct AvatarView: View {
    let id: String
    var body: some View {
        Canvas { context, size in
            let palettes: [(UInt32, UInt32)] = [(0x16A34A,0xFACC15),(0xEAB308,0x15803D),(0x2563EB,0xFACC15),(0x7C3AED,0x22C55E),(0xEA580C,0xFDE047),(0xDB2777,0x86EFAC),(0x0D9488,0xFDE047),(0x1E3A8A,0xFBBF24)]
            let index = (Int(id.suffix(2)) ?? 1) - 1
            let palette = palettes.indices.contains(index) ? palettes[index] : (0x848484,0xFFCB0A)
            context.scaleBy(x: size.width / 256, y: size.height / 256)
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 256, height: 256)), with: .color(Color(hex: palette.0)))
            context.fill(Path(ellipseIn: CGRect(x: 78, y: 52, width: 100, height: 100)), with: .color(Color(hex: 0xFFF7ED)))
            var body = Path(); body.move(to: CGPoint(x: 42, y: 234))
            body.addCurve(to: CGPoint(x: 128, y: 158), control1: CGPoint(x: 51, y: 184), control2: CGPoint(x: 82, y: 158))
            body.addCurve(to: CGPoint(x: 214, y: 234), control1: CGPoint(x: 174, y: 158), control2: CGPoint(x: 205, y: 184))
            context.fill(body, with: .color(Color(hex: 0xFFF7ED)))
            for x in [102,142] { context.fill(Path(ellipseIn: CGRect(x: x, y: 90, width: 12, height: 12)), with: .color(Color(hex: 0x1F2937))) }
            var smile = Path(); smile.move(to: CGPoint(x: 108, y: 124))
            smile.addCurve(to: CGPoint(x: 148, y: 124), control1: CGPoint(x: 121, y: 136), control2: CGPoint(x: 135, y: 136))
            context.stroke(smile, with: .color(Color(hex: 0x1F2937)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: 188, y: 32, width: 36, height: 36)), with: .color(Color(hex: palette.1)))
        }.aspectRatio(1, contentMode: .fit).clipShape(Circle()).accessibilityLabel("Profil avatarı")
    }
}

extension View {
    func pagePadding() -> some View { self.padding(.horizontal, 24).padding(.vertical, 16).frame(maxWidth: 700) }
    func dismissKeyboardToolbar() -> some View {
        self.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Bitti") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
    }
}
