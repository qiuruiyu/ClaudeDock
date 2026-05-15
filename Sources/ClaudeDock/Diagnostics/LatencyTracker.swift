import Foundation

final class LatencyTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var ring: [Int]
    private var idx = 0
    private var filled = 0
    private var _recentTimeoutCount = 0
    let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = capacity
        self.ring = Array(repeating: 0, count: capacity)
    }

    func record(milliseconds ms: Int) {
        lock.lock(); defer { lock.unlock() }
        ring[idx] = ms
        idx = (idx + 1) % capacity
        filled = min(filled + 1, capacity)
    }

    func recordTimeout() {
        lock.lock(); defer { lock.unlock() }
        _recentTimeoutCount += 1
    }

    var recentTimeoutCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _recentTimeoutCount
    }

    var allSamples: [Int] {
        lock.lock(); defer { lock.unlock() }
        return Array(ring.prefix(filled))
    }

    var median: Int? {
        let samples = allSamples.sorted()
        guard !samples.isEmpty else { return nil }
        let mid = samples.count / 2
        if samples.count.isMultiple(of: 2) {
            return (samples[mid - 1] + samples[mid]) / 2
        }
        return samples[mid]
    }
}
