import CoreMotion
import Foundation

/// Never streams for longer than a session. Raw accelerometer needs no authorisation
/// on iOS; `unavailable` is therefore a simulator/hardware fact, not a denial.
@Observable
final class MotionDetector {
    private(set) var isRunning = false
    private(set) var unavailable = false

    /// Peak |Δ| in the current 110 ms bucket, for the trace.
    var onSample: ((Double) -> Void)?
    var onPickup: ((TimeInterval) -> Void)?

    var threshold = Constants.sensitivityLadder[Constants.defaultSensitivity - 1]

    private let motion = CMMotionManager()
    private var lastMagnitude: Double?
    private var stillSince: TimeInterval?
    private var lastPickup: TimeInterval = 0
    private var bucketPeak: Double = 0
    private var bucketStart: TimeInterval = 0

    func start() {
        guard motion.isAccelerometerAvailable else {
            unavailable = true
            return
        }
        guard !isRunning else { return }
        isRunning = true
        lastMagnitude = nil
        stillSince = nil
        bucketStart = 0

        motion.accelerometerUpdateInterval = 0.1  // 10 Hz
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            self.consume(
                x: a.x, y: a.y, z: a.z, now: Date().timeIntervalSince1970)
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopAccelerometerUpdates()
        isRunning = false
    }

    /// Split out so the replay harness can drive it without CoreMotion.
    func consume(x: Double, y: Double, z: Double, now: TimeInterval) {
        let magnitude = sqrt(x * x + y * y + z * z)
        defer { lastMagnitude = magnitude }
        guard let last = lastMagnitude else { return }
        let d = abs(magnitude - last)

        // Trace: peak per bucket.
        if bucketStart == 0 { bucketStart = now }
        bucketPeak = max(bucketPeak, d)
        if now - bucketStart >= 0.11 {
            onSample?(bucketPeak)
            bucketPeak = 0
            bucketStart = now
        }

        if d < Constants.stillnessDelta {
            if stillSince == nil { stillSince = now }
            return
        }

        // Any sample above the noise floor ends the rest period. Leaving the middle
        // band untouched would let a stale `stillSince` satisfy the rest rule on a
        // phone that has been moving gently the whole time.
        let rested = stillSince.map { now - $0 } ?? 0
        stillSince = nil

        guard d > threshold else { return }
        guard rested > Constants.restBeforePickup else { return }
        guard now - lastPickup > Constants.pickupDebounce else { return }
        lastPickup = now
        onPickup?(now)
    }
}
