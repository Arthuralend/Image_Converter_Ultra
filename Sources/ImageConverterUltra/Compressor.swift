import Foundation

enum ImageKind {
    case jpeg, png, gif

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "jpe": self = .jpeg
        case "png": self = .png
        case "gif": self = .gif
        default: return nil
        }
    }
}

enum Prefs {
    static let jpegKey = "jpegQuality", pngKey = "pngQuality", gifKey = "gifQuality"
    static let bestKey = "bestQuality"
    /// Slower, higher-fidelity encoding (default on).
    static var best: Bool {
        UserDefaults.standard.object(forKey: bestKey) == nil ? true : UserDefaults.standard.bool(forKey: bestKey)
    }
    static var jpeg: Int { value(jpegKey, 90) }
    static var png: Int { value(pngKey, 80) }
    static var gif: Int { value(gifKey, 80) }
    private static func value(_ k: String, _ d: Int) -> Int {
        UserDefaults.standard.object(forKey: k) == nil ? d : UserDefaults.standard.integer(forKey: k)
    }
}

enum Outcome {
    case compressed(before: Int, after: Int)
    case skipped(String)
}

struct CompressError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Compressor {
    /// Compresses `url` in place. The original goes to the Trash, the compressed file takes its path.
    static func process(_ url: URL) async throws -> Outcome {
        guard let kind = ImageKind(url: url) else { return .skipped("Unsupported format") }
        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let before = (attrs[.size] as? Int) ?? 0

        let tmp = fm.temporaryDirectory
            .appendingPathComponent("ImageConverterUltra-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension.lowercased())
        defer { try? fm.removeItem(at: tmp) }

        switch kind {
        case .jpeg:
            guard let exe = Tools.path(for: "cjpegli") else { throw CompressError(message: "cjpegli (JPEGli) not found") }
            let base = [url.path, tmp.path, "-q", String(Prefs.jpeg)]
            var r = try await Tools.run(exe, Prefs.best ? base + ["--chroma_subsampling=444", "-p", "2"] : base)
            if r.status != 0 && Prefs.best { r = try await Tools.run(exe, base) } // fall back to plain settings
            guard r.status == 0 else { throw CompressError(message: "cjpegli: \(r.stderr.suffix(200))") }
            try Metadata.transplantJPEG(from: url, into: tmp)
        case .png:
            guard let exe = Tools.path(for: "pngquant") else { throw CompressError(message: "pngquant not found") }
            let q = Prefs.png
            let r = try await Tools.run(exe, ["--quality", "0-\(q)", "--speed", Prefs.best ? "1" : "4", "--force",
                                              "--output", tmp.path, "--", url.path])
            if r.status == 98 || r.status == 99 { return .skipped("No gain") }
            guard r.status == 0 else { throw CompressError(message: "pngquant: \(r.stderr.suffix(200))") }
            try Metadata.transplantPNG(from: url, into: tmp)
        case .gif:
            guard let exe = Tools.path(for: "gifsicle") else { throw CompressError(message: "gifsicle not found") }
            let r = try await Tools.run(exe, ["-O3", "--lossy=\(Prefs.gif)", "-o", tmp.path, url.path])
            guard r.status == 0 else { throw CompressError(message: "gifsicle: \(r.stderr.suffix(200))") }
        }

        let after = (try fm.attributesOfItem(atPath: tmp.path)[.size] as? Int) ?? 0
        guard after > 0 else { throw CompressError(message: "Empty output") }
        guard after < before else { return .skipped("Already optimal") }

        // Keep timestamps / permissions of the original.
        var keep: [FileAttributeKey: Any] = [:]
        for k in [FileAttributeKey.modificationDate, .creationDate, .posixPermissions] {
            if let v = attrs[k] { keep[k] = v }
        }
        try? fm.setAttributes(keep, ofItemAtPath: tmp.path)

        var trashed: NSURL?
        try fm.trashItem(at: url, resultingItemURL: &trashed)
        do {
            try fm.moveItem(at: tmp, to: url)
        } catch {
            if let t = trashed as URL? { try? fm.moveItem(at: t, to: url) } // roll back
            throw error
        }
        return .compressed(before: before, after: after)
    }

    /// Expands dropped files/folders into supported image files (recursive, skips hidden files).
    static func collect(_ urls: [URL]) -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default
        for u in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: u.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let en = fm.enumerator(at: u, includingPropertiesForKeys: [.isRegularFileKey],
                                       options: [.skipsHiddenFiles, .skipsPackageDescendants])
                while let f = en?.nextObject() as? URL {
                    if ImageKind(url: f) != nil, (try? f.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                        out.append(f)
                    }
                }
            } else if ImageKind(url: u) != nil {
                out.append(u)
            }
        }
        return out
    }
}
