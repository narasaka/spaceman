// Lists Notification Center banners and clicks one with a real mouse event.
import AppKit
import ApplicationServices

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}
func children(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func frame(_ e: AXUIElement) -> CGRect? {
    guard let p = attr(e, kAXPositionAttribute), let s = attr(e, kAXSizeAttribute) else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
    return CGRect(origin: pt, size: sz)
}
func dump(_ e: AXUIElement, _ depth: Int, _ found: inout [(AXUIElement, CGRect, String)]) {
    let role = attr(e, kAXRoleAttribute) as? String ?? "?"
    let sub = attr(e, kAXSubroleAttribute) as? String ?? ""
    let desc = attr(e, kAXDescriptionAttribute) as? String ?? ""
    let f = frame(e)
    print(String(repeating: "  ", count: depth) + "\(role) \(sub) desc=\(desc.prefix(80)) \(f.map { "\($0)" } ?? "")")
    if sub == "AXNotificationCenterBanner" || sub == "AXNotificationCenterAlert", let f { found.append((e, f, desc)) }
    if depth < 12 { for c in children(e) { dump(c, depth + 1, &found) } }
}
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
guard let nc = apps.first else { print("no NotificationCenter"); exit(1) }
let app = AXUIElementCreateApplication(nc.processIdentifier)
let mode = CommandLine.arguments.dropFirst().first ?? "list"
let needle = CommandLine.arguments.dropFirst(2).first ?? ""
let screenWidth = NSScreen.screens.map { $0.frame.maxX }.max() ?? 0
var target: (AXUIElement, CGRect, String)? = nil
// Wait (up to 5 s) until the banner has finished sliding in and sits fully on screen.
for attempt in 0..<50 {
    var found: [(AXUIElement, CGRect, String)] = []
    for w in (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { dump(w, 0, &found) }
    if mode != "click" { exit(0) }
    if let match = found.first(where: { needle.isEmpty || $0.2.contains(needle) }), match.1.maxX <= screenWidth - 4 {
        target = match; break
    }
    _ = attempt; usleep(100_000)
}
guard let target else { print("no settled banner matching \(needle)"); exit(2) }
let point = CGPoint(x: target.1.midX, y: target.1.midY)
print("clicking banner \(target.2.prefix(80)) at \(point)")
let src = CGEventSource(stateID: .hidSystemState)
CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(150_000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(60_000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
print("clicked")
