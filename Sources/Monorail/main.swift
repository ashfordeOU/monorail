#if os(macOS)
import AppKit

// `Monorail --mcp` runs the MCP server for AI assistants instead of the app.
if CommandLine.arguments.contains("--mcp") { MCPServer.run() }
// `Monorail --self-test` checks the app's own pieces without touching any windows (run in CI).
if CommandLine.arguments.contains("--self-test") { exit(SelfTest.run()) }
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
