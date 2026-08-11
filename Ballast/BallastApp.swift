import SwiftUI

@main
struct BallastApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    model.setForeground(phase == .active)
                }
        }
    }
}

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        switch model.route {
        case .setup:
            SetupView(model: model)
        case .session:
            SessionView(model: model)
        case .asking:
            // No transition, deliberately.
            AskingView(model: model)
        case .closed:
            ClosedView(model: model)
        }
    }
}
