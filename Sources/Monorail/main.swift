#if os(macOS)
import AppKit

// `Monorail --mcp` runs the MCP server for AI assistants instead of the app.
if CommandLine.arguments.contains("--mcp") { MCPServer.run() }
// `Monorail --self-test` checks the app's own pieces without touching any windows (run in CI).
if CommandLine.arguments.contains("--self-test") { exit(SelfTest.run()) }
// `Monorail --render-screens <folder>` draws the welcome tour and What's New to PNG files (CI).
if let index = CommandLine.arguments.firstIndex(of: "--render-screens"), CommandLine.arguments.count > index + 1 {
    exit(ScreenRender.run(into: URL(fileURLWithPath: CommandLine.arguments[index + 1])))
}
// `Monorail --shared-engine` tries the platform-free engine on this Mac's real windows (docs/PLATFORMS.md).
if SharedEngineRunner.isRequested { SharedEngineRunner.run() }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
#else
print("Monorail is a macOS app. Only MonorailCore builds on this platform.")
#endif
