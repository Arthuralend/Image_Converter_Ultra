import SwiftUI

struct ContentView: View {
    @StateObject private var proc = Processor.shared
    @AppStorage(Prefs.jpegKey) private var jpegQ = 90
    @AppStorage(Prefs.pngKey) private var pngQ = 80
    @AppStorage(Prefs.gifKey) private var gifQ = 80
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 12) {
            dropZone
            settings
            if !proc.items.isEmpty { results }
        }
        .padding(16)
        .dropDestination(for: URL.self) { urls, _ in
            proc.add(urls); return true
        } isTargeted: { targeted = $0 }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(targeted ? Color.accentColor : .secondary)
                .background(targeted ? Color.accentColor.opacity(0.08) : .clear)
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 36))
                Text("Перетащите фото или папки сюда").font(.headline)
                Text("JPEG · PNG · GIF — файл будет заменён сжатым, оригинал уйдёт в Корзину")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding()
        }
        .frame(height: 150)
    }

    private var settings: some View {
        GroupBox("Качество") {
            VStack(spacing: 4) {
                slider("JPEG (JPEGli)", $jpegQ, 50...100)
                slider("PNG", $pngQ, 30...100)
                slider("GIF", $gifQ, 10...100)
            }
        }
    }

    private func slider(_ title: String, _ v: Binding<Int>, _ r: ClosedRange<Int>) -> some View {
        HStack {
            Text(title).frame(width: 110, alignment: .leading)
            Slider(value: Binding(get: { Double(v.wrappedValue) }, set: { v.wrappedValue = Int($0) }),
                   in: Double(r.lowerBound)...Double(r.upperBound), step: 1)
            Text("\(v.wrappedValue)").monospacedDigit().frame(width: 32, alignment: .trailing)
        }
    }

    private var results: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Сэкономлено: \(fmt(proc.savedBytes))").font(.subheadline.bold())
                Spacer()
                Button("Очистить") { proc.clear() }.disabled(proc.busy)
            }
            List(proc.items) { item in
                HStack {
                    Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    status(item.status)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder private func status(_ s: Item.Status) -> some View {
        switch s {
        case .waiting: Text("в очереди").foregroundStyle(.secondary)
        case .working: ProgressView().controlSize(.small)
        case let .done(b, a):
            Text("\(fmt(b)) → \(fmt(a))  −\(100 - a * 100 / max(b, 1))%").foregroundStyle(.green)
        case let .skipped(w): Text(w).foregroundStyle(.secondary)
        case let .failed(m): Text(m).foregroundStyle(.red).lineLimit(1).help(m)
        }
    }

    private func fmt(_ n: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }
}
