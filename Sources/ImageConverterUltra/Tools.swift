import Foundation

/// Locates the command-line encoders: cjpegli (JPEGli), pngquant, gifsicle.
/// Looks in the app bundle first (Contents/Resources/bin), then Homebrew locations.
enum Tools {
    static func path(for name: String) -> URL? {
        var dirs: [String] = []
        if let res = Bundle.main.resourceURL {
            dirs.append(res.appendingPathComponent("bin").path)
        }
        dirs += ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]
        for d in dirs {
            let p = (d as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
        }
        return nil
    }

    static func run(_ exe: URL, _ args: [String]) async throws -> (status: Int32, stderr: String) {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = exe
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            let err = Pipe()
            p.standardError = err
            p.terminationHandler = { proc in
                let data = err.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (proc.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}
