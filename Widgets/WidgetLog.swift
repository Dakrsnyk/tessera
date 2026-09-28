import Foundation
import os

/// Timings of the widget extension, read from the simulator log by the CI placement test.
enum WidgetLog {
    static let logger = Logger(subsystem: "com.dakrsnyk.tessera.widgets", category: "timeline")
}
