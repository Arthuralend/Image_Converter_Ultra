import Foundation
import SwiftUI

struct Item: Identifiable {
    enum Status {
        case waiting, working
        case done(before: Int, after: Int)
        case skipped(String)
        case failed(String)
    }
    let id = UUID()
    let url: URL
    var status: Status = .waiting
}

@MainActor
final class Processor: ObservableObject {
    static let shared = Processor()
    @Published var items: [Item] = []
    @Published var savedBytes = 0

    var busy: Bool {
        items.contains { if case .waiting = $0.status { return true }; if case .working = $0.status { return true }; return false }
    }

    func add(_ urls: [URL]) {
        Task {
            let files = await Task.detached { Compressor.collect(urls) }.value
            guard !files.isEmpty else { return }
            let new = files.map { Item(url: $0) }
            items.insert(contentsOf: new, at: 0)
            await run(new)
        }
    }

    private func run(_ batch: [Item]) async {
        let limit = max(2, ProcessInfo.processInfo.activeProcessorCount)
        await withTaskGroup(of: Void.self) { group in
            var it = batch.makeIterator()
            for _ in 0..<limit {
                guard let item = it.next() else { break }
                group.addTask { await self.handle(item) }
            }
            while await group.next() != nil {
                if let item = it.next() { group.addTask { await self.handle(item) } }
            }
        }
    }

    private func handle(_ item: Item) async {
        set(item.id, .working)
        do {
            switch try await Compressor.process(item.url) {
            case let .compressed(b, a):
                savedBytes += b - a
                set(item.id, .done(before: b, after: a))
            case let .skipped(why):
                set(item.id, .skipped(why))
            }
        } catch {
            set(item.id, .failed(error.localizedDescription))
        }
    }

    private func set(_ id: UUID, _ s: Item.Status) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].status = s }
    }

    func clear() { items.removeAll { if case .working = $0.status { return false }; if case .waiting = $0.status { return false }; return true } }
}
