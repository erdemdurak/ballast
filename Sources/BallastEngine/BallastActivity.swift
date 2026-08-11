#if os(iOS)
    import ActivityKit
    import Foundation

    /// The Lock Screen surface. iOS cannot tell a suspended app that the phone was
    /// picked up — but picking the phone up always shows the Lock Screen, so the task
    /// is put there instead of trying to detect the reach.
    ///
    /// The app is suspended for most of a session and cannot push updates, so the
    /// countdown is rendered with a self-running timer rather than by pushing state.
    public struct BallastAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            /// When the next pick-up starts asking. Nil means nothing is owed.
            public var armedAt: Date?
            /// True once a question is outstanding.
            public var asking: Bool

            public init(armedAt: Date? = nil, asking: Bool = false) {
                self.armedAt = armedAt
                self.asking = asking
            }
        }

        public var task: String

        public init(task: String) {
            self.task = task
        }
    }
#endif
