import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Registration only succeeds for
/// a real .app bundle; from `swift run` it throws and is logged — it will work
/// once the app is packaged.
enum LoginItem {
    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Snip login item update failed: \(error.localizedDescription)")
        }
    }
}
