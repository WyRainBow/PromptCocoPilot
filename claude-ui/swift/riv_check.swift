import Foundation
import RiveRuntime

let args = CommandLine.arguments
let rivName = args.count > 1 ? args[1] : "IPDefaultIdle"
print("🔍 Check SM inputs via RiveModel: \(rivName).riv\n")

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

let model = RiveModel(riveFile: file)
let vm = RiveViewModel(model, stateMachineName: "State Machine 1", fit: .contain, artboardName: "idle")
print("✅ Created RiveViewModel")

if let sm = model.stateMachine {
    print("✅ Got state machine")
    let inputs = sm.inputs
    print("  inputs.count = \(inputs.count)")
    for (i, input) in inputs.enumerated() {
        let typeName: String
        switch input.type {
        case .trigger:  typeName = "TRIGGER ⭐"
        case .number:  typeName = "number"
        case .boolean: typeName = "boolean"
        @unknown default: typeName = "unknown"
        }
        print("  [\(i)] \"\(input.name)\" = \(typeName)")
    }
} else {
    print("❌ model.stateMachine is nil")
}

print("\n✅ Done.")
