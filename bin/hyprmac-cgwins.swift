// Prints {"<window id>": "<owner app name>"} for every layer-0 window, on or off screen.
import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var out: [String: String] = [:]
for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
    if let id = w[kCGWindowNumber as String] as? Int, let app = w[kCGWindowOwnerName as String] as? String {
        out[String(id)] = app
    }
}
FileHandle.standardOutput.write(try! JSONSerialization.data(withJSONObject: out))
