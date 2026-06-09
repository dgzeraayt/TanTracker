import Foundation
import Combine

@MainActor
final class ExposureTimer: ObservableObject {
    @Published var remaining: TimeInterval = 0
    @Published var total: TimeInterval = 0
    @Published var running = false
    @Published var finished = false

    private var timer: AnyCancellable?
    private var endDate: Date?

    var elapsed: TimeInterval { max(0, total - remaining) }
    var progress: Double { total > 0 ? min(1, elapsed / total) : 0 }

    var remainingLabel: String {
        let s = Int(max(0, remaining))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func configure(minutes: Int) {
        total = TimeInterval(minutes * 60)
        remaining = total
        finished = false
    }

    func start() {
        guard !running, remaining > 0 else { return }
        running = true
        endDate = Date().addingTimeInterval(remaining)
        timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        running = false
        timer?.cancel()
    }

    func reset() {
        pause()
        remaining = total
        finished = false
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            running = false
            finished = true
            timer?.cancel()
        }
    }
}
