import SwiftUI
import WidgetKit

@main
struct BallastWidgetBundle: WidgetBundle {
    var body: some Widget {
        BallastLiveActivity()
        BallastTaskWidget()
    }
}
