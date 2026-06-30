import Foundation
import RiveRuntime

let args = CommandLine.arguments
// Allow override: pass a .riv filename as arg  (e.g.  ./riv_diag IPDefaultIdle)
let rivName = args.count > 1 ? args[1] : "IPDefaultIdle"
print("🔍 Dumping Rive file: \(rivName).riv\n")

// Bundle.main.executableURL = the riv_diag binary itself (swift/riv_diag):
let exeDir = Bundle.main.executableURL?.deletingLastPathComponent()
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

// Search paths (in order):
//   1. build/        (next to executable when normally run)
//   2. Resources/    (in the swift/ source dir, for dev: swift/Resources/)
let buildURL     = exeDir.appendingPathComponent("\(rivName).riv")
let resourcesURL = exeDir
    .appendingPathComponent("Resources")
    .appendingPathComponent("\(rivName).riv")

let fileURL: URL?
if FileManager.default.fileExists(atPath: buildURL.path) {
    fileURL = buildURL
} else if FileManager.default.fileExists(atPath: resourcesURL.path) {
    fileURL = resourcesURL
} else {
    // Last resort: current working dir
    let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("\(rivName).riv")
    fileURL = FileManager.default.fileExists(atPath: cwdURL.path) ? cwdURL : nil
}

guard let url = fileURL else {
    print("❌ File not found: \(rivName).riv")
    print("  Searched:")
    print("    • \(buildURL.path)")
    print("    • \(resourcesURL.path)")
    print("\nUsage:  ./riv_diag IPDefaultIdle")
    print("        ./riv_diag IPDefaultThinking")
    exit(1)
}

print("📄 Loading: \(url.path)\n")
let data = try! Data(contentsOf: url)
let file = try! RiveFile(data: data, loadCdn: false)

let artboardNames = file.artboardNames()
print("=== RiveFile ===")
print("  artboards: \(artboardNames)")
print("\n=== Artboards (\(artboardNames.count)) ===")
for name in artboardNames {
    print("  • \"\(name)\"")
    let ab = try! file.artboard(fromName: name)
    let smNames = ab.stateMachineNames()
    let animNames = ab.animationNames()
    print("    state machines: \(smNames)")
    print("    animations:     \(animNames)")
}

print("\n✅ Done.")
