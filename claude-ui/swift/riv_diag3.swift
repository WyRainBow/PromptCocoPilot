import Foundation
import RiveRuntime

let args = CommandLine.arguments
let rivName = args.count > 1 ? args[1] : "IPDefaultIdle"
print("🔍 Test Rive playback: \(rivName).riv\n")

let exeDir = Bundle.main.executableURL?.deletingLastPathComponent()
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let buildURL     = exeDir.appendingPathComponent("\(rivName).riv")
let resourcesURL = exeDir.appendingPathComponent("Resources/\(rivName).riv")

let url: URL
if FileManager.default.fileExists(atPath: buildURL.path) {
    url = buildURL
} else if FileManager.default.fileExists(atPath: resourcesURL.path) {
    url = resourcesURL
} else {
    print("❌ File not found")
    exit(1)
}

let data = try! Data(contentsOf: url)
let file = try! RiveFile(data: data, loadCdn: false)

// List all animations in the idle artboard
guard let ab = try? file.artboard(fromName: "idle") else {
    print("❌ Could not load 'idle' artboard")
    exit(1)
}
print("=== Artboard: idle ===")
print("  stateMachines: \(ab.stateMachineNames())")
print("  animations:")
for i in 0..<ab.animationCount() {
    let anim = try! ab.animation(from: i)
    print("    [\(i)] \"\(anim.name())\" duration=\(String(format: "%.2f", anim.duration()))s")
}

print("\n=== Testing RiveViewModel with stateMachine ===")
do {
    let vm = RiveViewModel(RiveModel(riveFile: file),
                            stateMachineName: "State Machine 1",
                            fit: .contain,
                            artboardName: "idle")
    print("  ✅ Created with SM 'State Machine 1'")
} catch {
    print("  ❌ Error with SM: \(error)")
}

print("\n=== Testing RiveViewModel with animation names ===")
for i in 0..<ab.animationCount() {
    let anim = try! ab.animation(from: i)
    let animName = anim.name()
    do {
        let vm = RiveViewModel(RiveModel(riveFile: file),
                                animationName: animName,
                                fit: .contain,
                                artboardName: "idle")
        print("  ✅ [\(i)] animation='\(animName)'")
    } catch {
        print("  ❌ [\(i)] animation='\(animName)': \(error)")
    }
}

print("\n✅ Done.")
