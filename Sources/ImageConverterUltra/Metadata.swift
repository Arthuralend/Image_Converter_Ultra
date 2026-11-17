import Foundation

/// Pure-Swift metadata transplant so EXIF / XMP / ICC / IPTC survive recompression.
enum Metadata {

    // MARK: JPEG

    private struct JSeg { var marker: UInt8; var bytes: Data } // bytes = FF xx len len payload

    private static func jpegHeader(_ d: Data) -> (segs: [JSeg], rest: Data)? {
        guard d.count > 4, d[d.startIndex] == 0xFF, d[d.startIndex + 1] == 0xD8 else { return nil }
        var segs: [JSeg] = []
        var pos = d.startIndex + 2
        while pos + 4 <= d.endIndex {
            guard d[pos] == 0xFF else { return nil }
            let m = d[pos + 1]
            if m == 0xDA || m == 0xD9 { break }
            let len = Int(d[pos + 2]) << 8 | Int(d[pos + 3])
            guard len >= 2, pos + 2 + len <= d.endIndex else { return nil }
            segs.append(JSeg(marker: m, bytes: d.subdata(in: pos..<(pos + 2 + len))))
            pos += 2 + len
        }
        return (segs, d.subdata(in: pos..<d.endIndex))
    }

    private static func hasPrefix(_ s: JSeg, _ p: String) -> Bool {
        let payload = s.bytes.dropFirst(4)
        return payload.starts(with: Array(p.utf8))
    }

    /// Metadata segments worth keeping: EXIF/XMP (APP1), ICC (APP2), IPTC/Photoshop (APP13), comments.
    private static func isMeta(_ s: JSeg) -> Bool {
        switch s.marker {
        case 0xE1, 0xED, 0xFE: return true
        case 0xE2: return hasPrefix(s, "ICC_PROFILE")
        default: return false
        }
    }

    static func transplantJPEG(from src: URL, into dst: URL) throws {
        guard let a = jpegHeader(try Data(contentsOf: src)),
              let b = jpegHeader(try Data(contentsOf: dst)) else { return }
        let meta = a.segs.filter(isMeta)
        if meta.isEmpty { return }
        var out = Data([0xFF, 0xD8])
        let kept = b.segs.filter { !isMeta($0) }
        // JFIF (APP0) first, then metadata, then other segments.
        for s in kept where s.marker == 0xE0 { out.append(s.bytes) }
        for s in meta { out.append(s.bytes) }
        for s in kept where s.marker != 0xE0 { out.append(s.bytes) }
        out.append(b.rest)
        try out.write(to: dst, options: .atomic)
    }

    // MARK: PNG

    private static let pngSig = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    private struct PChunk { var type: String; var raw: Data }

    private static func pngChunks(_ d: Data) -> [PChunk]? {
        guard d.count > 8, d.prefix(8) == pngSig else { return nil }
        var out: [PChunk] = []
        var pos = d.startIndex + 8
        while pos + 12 <= d.endIndex {
            let len = Int(d[pos]) << 24 | Int(d[pos+1]) << 16 | Int(d[pos+2]) << 8 | Int(d[pos+3])
            guard pos + 12 + len <= d.endIndex else { return nil }
            let type = String(decoding: d[(pos + 4)..<(pos + 8)], as: UTF8.self)
            out.append(PChunk(type: type, raw: d.subdata(in: pos..<(pos + 12 + len))))
            pos += 12 + len
        }
        return out
    }

    /// Ancillary chunks that are independent of pixel/palette data.
    private static let pngKeep: Set<String> =
        ["iCCP", "sRGB", "gAMA", "cHRM", "eXIf", "tEXt", "zTXt", "iTXt", "pHYs", "tIME"]

    static func transplantPNG(from src: URL, into dst: URL) throws {
        guard let a = pngChunks(try Data(contentsOf: src)),
              let b = pngChunks(try Data(contentsOf: dst)),
              b.first?.type == "IHDR" else { return }
        let present = Set(b.map(\.type))
        let colorSpaceTypes: Set<String> = ["iCCP", "sRGB"]
        let hasColor = !present.isDisjoint(with: colorSpaceTypes)
        var add: [PChunk] = []
        for c in a where pngKeep.contains(c.type) {
            // Repeatable text chunks: skip if identical already present.
            let repeatable = ["tEXt", "zTXt", "iTXt"].contains(c.type)
            if !repeatable && present.contains(c.type) { continue }
            if hasColor && colorSpaceTypes.contains(c.type) { continue }
            if repeatable && b.contains(where: { $0.raw == c.raw }) { continue }
            add.append(c)
        }
        // Don't add both iCCP and sRGB from the source.
        if add.contains(where: { $0.type == "iCCP" }) { add.removeAll { $0.type == "sRGB" } }
        if add.isEmpty { return }
        var out = pngSig
        out.append(b[0].raw)
        for c in add { out.append(c.raw) }
        for c in b.dropFirst() { out.append(c.raw) }
        try out.write(to: dst, options: .atomic)
    }
}
