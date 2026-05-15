import Foundation
import Testing
@testable import ClaudeDock

@Suite struct LatencyTrackerTests {
    @Test func emptyTrackerReportsNoStats() {
        let t = LatencyTracker()
        #expect(t.median == nil)
        #expect(t.recentTimeoutCount == 0)
    }

    @Test func medianOfOddSampleSet() {
        let t = LatencyTracker()
        t.record(milliseconds: 10)
        t.record(milliseconds: 50)
        t.record(milliseconds: 30)
        #expect(t.median == 30)
    }

    @Test func ringBufferDropsOldestWhenFull() {
        let t = LatencyTracker(capacity: 3)
        t.record(milliseconds: 1)
        t.record(milliseconds: 2)
        t.record(milliseconds: 3)
        t.record(milliseconds: 100)   // evicts 1
        #expect(t.allSamples.sorted() == [2, 3, 100])
        #expect(t.median == 3)
    }

    @Test func timeoutsAreCountedSeparately() {
        let t = LatencyTracker()
        t.recordTimeout()
        t.recordTimeout()
        #expect(t.recentTimeoutCount == 2)
    }
}
