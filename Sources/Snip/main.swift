import AppKit
import Foundation

// Dispatch: a recognised CLI argument (`capture` or an existing file path) runs
// the headless uploader; anything else launches the menubar app.
let cliArgs = Array(CommandLine.arguments.dropFirst())
if cliArgs.first == "render-snippet" {
    runRenderSnippet(cliArgs)  // never returns
}
if let first = cliArgs.first,
   first == "capture" || FileManager.default.fileExists(atPath: first) {
    runCLI(cliArgs)  // never returns
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menubar agent, no dock icon (LSUIElement-equivalent)
app.run()
