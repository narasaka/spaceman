// A disposable regular app with one titled window, for live Spaceman tests.
import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 600, height: 400), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
w.title = "spaceman-R"
w.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
