import Foundation
import Combine

@MainActor
final class WizardState: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, plugin, notchDock, hotkey, done
    }
    @Published var current: Step = .welcome

    func next() {
        let all = Step.allCases
        if let i = all.firstIndex(of: current), i + 1 < all.count {
            current = all[i + 1]
        }
    }

    func back() {
        let all = Step.allCases
        if let i = all.firstIndex(of: current), i > 0 {
            current = all[i - 1]
        }
    }

    func skip() {
        current = .done
    }
}
